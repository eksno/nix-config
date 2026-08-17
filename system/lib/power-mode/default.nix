{ config, pkgs, lib, ... }:

let
  power-mode = pkgs.writeShellScriptBin "power-mode" ''
    set -euo pipefail

    # Self-elevate to root — sysfs and RAPL require it
    if [ "$(id -u)" != "0" ]; then
      exec /run/wrappers/bin/sudo "$(readlink -f "$0")" "$@"
    fi

    # Auto-detect battery
    BAT=""
    for b in /sys/class/power_supply/BAT*; do
      [ -f "$b/energy_now" ] && BAT="$b" && break
    done
    if [ -z "$BAT" ]; then
      echo "No battery found." >&2
      exit 1
    fi

    PSTATE="/sys/devices/system/cpu/intel_pstate"
    RAPL="/sys/class/powercap/intel-rapl:0"
    PLATFORM_PROFILE="/sys/firmware/acpi/platform_profile"

    # Auto-detect iGPU card path (look for gt_max_freq_mhz)
    GPU_CARD=""
    for card in /sys/class/drm/card*; do
      [ -f "$card/gt_max_freq_mhz" ] && GPU_CARD="$card" && break
    done

    # Detect true hardware max frequency (turbo must be on to read it)
    if [ -f "$PSTATE/no_turbo" ]; then
      _orig_turbo=$(cat "$PSTATE/no_turbo")
      echo 0 > "$PSTATE/no_turbo"
    fi
    CPU_MAX=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo 4500000)
    CPU_MIN=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq 2>/dev/null || echo 400000)
    CPU_FLOOR=800000  # Lowest useful freq — no power savings below this
    if [ -n "''${_orig_turbo:-}" ]; then
      echo "$_orig_turbo" > "$PSTATE/no_turbo"
    fi

    # Detect iGPU hardware frequency range (per-GT files)
    GPU_MAX=""
    GPU_MIN=""
    if [ -n "$GPU_CARD" ]; then
      GPU_MAX=$(cat "$GPU_CARD/gt/gt0/rps_RP0_freq_mhz" 2>/dev/null || cat "$GPU_CARD/gt_RP0_freq_mhz" 2>/dev/null || echo "")
      GPU_MIN=$(cat "$GPU_CARD/gt/gt0/rps_RPn_freq_mhz" 2>/dev/null || cat "$GPU_CARD/gt_RPn_freq_mhz" 2>/dev/null || echo "100")
    fi

    # Auto-detect WiFi interface
    WIFI_IFACE=""
    WIFI_IFACE=$(${pkgs.iw}/bin/iw dev 2>/dev/null | ${pkgs.gawk}/bin/awk '/Interface/{print $2; exit}' || echo "")

    # State dir for service coordination (volatile, cleared on reboot)
    STATE_DIR="/tmp/power-mode"
    mkdir -p "$STATE_DIR"
    chmod 1777 "$STATE_DIR" 2>/dev/null || true

    # Persistent data dir (calibration data survives reboots)
    DATA_DIR="/var/lib/power-mode"
    mkdir -p "$DATA_DIR" 2>/dev/null || true

    # Colors
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'

    calc() {
      ${pkgs.gawk}/bin/awk "BEGIN { printf \"%.''${2:-1}f\", $1 }"
    }

    calc_int() {
      ${pkgs.gawk}/bin/awk "BEGIN { printf \"%d\", $1 }"
    }

    bat_energy_wh() {
      calc "$(cat "$BAT/energy_now") / 1000000" 2
    }

    bat_percent() {
      cat "$BAT/capacity"
    }

    bat_watts() {
      local raw
      raw=$(cat "$BAT/power_now" 2>/dev/null || echo 0)
      if [ "$raw" = "0" ]; then
        echo "0.0"
      else
        calc "$raw / 1000000"
      fi
    }

    # Read power_now in microwatts with fallback (sysfs can vanish briefly during CPU hotplug)
    read_power_uw() {
      cat "$BAT/power_now" 2>/dev/null || echo 0
    }

    bat_status() {
      cat "$BAT/status"
    }

    is_bt_on() {
      ${pkgs.bluez}/bin/bluetoothctl show 2>/dev/null | grep -q "Powered: yes"
    }

    is_wifi_on() {
      ${pkgs.networkmanager}/bin/nmcli radio wifi 2>/dev/null | grep -q "enabled"
    }

    # ── Try-write with verification and availability caching ──
    try_write() {
      local path="$1" value="$2" lever_name="''${3:-}"
      local cache_file=""
      if [ -n "$lever_name" ]; then
        cache_file="$STATE_DIR/lever-''${lever_name}-available"
        # Cached as unavailable — skip silently
        if [ -f "$cache_file" ] && [ "$(cat "$cache_file")" = "0" ]; then
          return 1
        fi
      fi
      if [ ! -f "$path" ]; then
        [ -n "$cache_file" ] && echo "0" > "$cache_file"
        return 1
      fi
      echo "$value" > "$path" 2>/dev/null || {
        [ -n "$cache_file" ] && echo "0" > "$cache_file"
        return 1
      }
      # Verify readback
      local readback
      readback=$(cat "$path" 2>/dev/null || echo "")
      # Bracketed-option files (ASPM, SLPC): "[value] other options"
      if echo "$readback" | grep -q "\[$value\]"; then
        [ -n "$cache_file" ] && echo "1" > "$cache_file"
        return 0
      fi
      # Direct match (trim whitespace)
      local rb_trimmed val_trimmed
      rb_trimmed=$(echo "$readback" | tr -d '[:space:]')
      val_trimmed=$(echo "$value" | tr -d '[:space:]')
      if [ "$rb_trimmed" = "$val_trimmed" ]; then
        [ -n "$cache_file" ] && echo "1" > "$cache_file"
        return 0
      fi
      [ -n "$cache_file" ] && echo "0" > "$cache_file"
      return 1
    }

    # ── Core setters ──
    set_max_freq() {
      for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
        echo "$1" > "$f"
      done
    }

    set_min_freq() {
      for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq; do
        echo "$1" > "$f"
      done
    }

    set_turbo() {
      [ -f "$PSTATE/no_turbo" ] && echo "$1" > "$PSTATE/no_turbo"
    }

    set_rapl_uw() {
      if [ -d "$RAPL" ]; then
        echo "$1" > "$RAPL/constraint_0_power_limit_uw"
        echo "$(($1 + 2000000))" > "$RAPL/constraint_1_power_limit_uw"
      fi
    }

    set_platform_profile() {
      [ -f "$PLATFORM_PROFILE" ] && echo "$1" > "$PLATFORM_PROFILE" 2>/dev/null || true
    }

    set_governor() {
      for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "$1" > "$f"
      done
    }

    # ── New lever helpers ──
    set_epp() {
      for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
        echo "$1" > "$f" 2>/dev/null || true
      done
    }

    get_epp() {
      cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo "default"
    }

    set_igpu_max() {
      if [ -n "$GPU_CARD" ] && [ -d "$GPU_CARD/gt/gt0" ]; then
        for gt in "$GPU_CARD"/gt/gt*/rps_max_freq_mhz; do
          [ -f "$gt" ] && try_write "$gt" "$1" "igpu_max" || true
        done
      fi
    }

    get_igpu_max() {
      if [ -n "$GPU_CARD" ] && [ -f "$GPU_CARD/gt/gt0/rps_max_freq_mhz" ]; then
        cat "$GPU_CARD/gt/gt0/rps_max_freq_mhz" 2>/dev/null
      else
        echo ""
      fi
    }

    set_igpu_slpc() {
      if [ -n "$GPU_CARD" ] && [ -d "$GPU_CARD/gt/gt0" ]; then
        for gt in "$GPU_CARD"/gt/gt*/slpc_power_profile; do
          [ -f "$gt" ] && try_write "$gt" "$1" "igpu_slpc" || true
        done
      fi
    }

    get_igpu_slpc() {
      if [ -n "$GPU_CARD" ] && [ -f "$GPU_CARD/gt/gt0/slpc_power_profile" ]; then
        local raw
        raw=$(cat "$GPU_CARD/gt/gt0/slpc_power_profile" 2>/dev/null || echo "")
        # Parse bracketed value: "[base]    power_saving" -> "base"
        echo "$raw" | sed -n 's/.*\[\(.*\)\].*/\1/p'
      else
        echo ""
      fi
    }

    set_aspm() {
      try_write "/sys/module/pcie_aspm/parameters/policy" "$1" "aspm" || true
    }

    get_aspm() {
      local raw
      raw=$(cat /sys/module/pcie_aspm/parameters/policy 2>/dev/null || echo "")
      echo "$raw" | sed -n 's/.*\[\(.*\)\].*/\1/p'
    }

    set_wifi_powersave() {
      [ -n "$WIFI_IFACE" ] && ${pkgs.iw}/bin/iw dev "$WIFI_IFACE" set power_save "$1" 2>/dev/null || true
    }

    get_wifi_powersave() {
      if [ -n "$WIFI_IFACE" ]; then
        ${pkgs.iw}/bin/iw dev "$WIFI_IFACE" get power_save 2>/dev/null | ${pkgs.gawk}/bin/awk '{print tolower($NF)}'
      else
        echo ""
      fi
    }

    set_pci_pm() {
      for d in /sys/bus/pci/devices/*/power/control; do
        echo "$1" > "$d" 2>/dev/null || true
      done
    }

    get_pci_pm() {
      local auto=0 total=0
      for d in /sys/bus/pci/devices/*/power/control; do
        [ -f "$d" ] || continue
        total=$((total + 1))
        [ "$(cat "$d")" = "auto" ] && auto=$((auto + 1))
      done
      if [ "$auto" = "$total" ]; then
        echo "auto"
      elif [ "$auto" = "0" ]; then
        echo "on"
      else
        echo "$auto/$total auto"
      fi
    }

    # ── Charge limit ──
    set_charge_limit() {
      local limit="$1"
      if [ "$limit" -lt 20 ] || [ "$limit" -gt 100 ]; then
        echo -e "''${RED}Charge limit must be between 20 and 100.''${RESET}"
        return 1
      fi
      if [ ! -f "$BAT/charge_control_end_threshold" ]; then
        echo -e "''${RED}Battery does not support charge limit (charge_control_end_threshold not found).''${RESET}"
        return 1
      fi
      echo "$limit" > "$BAT/charge_control_end_threshold" 2>/dev/null || {
        echo -e "''${RED}Failed to set charge limit — write denied.''${RESET}"
        return 1
      }
      echo -e "''${GREEN}Charge limit set to ''${limit}%''${RESET}"
    }

    get_charge_limit() {
      if [ -f "$BAT/charge_control_end_threshold" ]; then
        cat "$BAT/charge_control_end_threshold" 2>/dev/null || echo "100"
      else
        echo ""
      fi
    }

    # ── Save / Restore state ──
    save_state() {
      [ -f "$STATE_DIR/saved-state" ] && return 0
      {
        echo "turbo=$(cat "$PSTATE/no_turbo" 2>/dev/null || echo "0")"
        echo "governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
        echo "cpu_max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)"
        echo "cpu_min=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq)"
        echo "rapl_pl1=$(cat "$RAPL/constraint_0_power_limit_uw" 2>/dev/null || echo "28000000")"
        echo "rapl_pl2=$(cat "$RAPL/constraint_1_power_limit_uw" 2>/dev/null || echo "30000000")"
        echo "epp=$(get_epp)"
        echo "platform_profile=$(cat "$PLATFORM_PROFILE" 2>/dev/null || echo "balanced")"
        echo "igpu_max=$(get_igpu_max)"
        echo "igpu_slpc=$(get_igpu_slpc)"
        echo "aspm=$(get_aspm)"
        echo "wifi_powersave=$(get_wifi_powersave)"
      } > "$STATE_DIR/saved-state"
      # Save per-device PCI runtime PM state (separate file — too many entries for key=val)
      for d in /sys/bus/pci/devices/*/power/control; do
        local dev
        dev=$(basename "$(dirname "$(dirname "$d")")")
        echo "$dev=$(cat "$d")"
      done > "$STATE_DIR/saved-pci-pm"
    }

    restore_state() {
      if [ -f "$STATE_DIR/saved-state" ]; then
        local turbo="" governor="" cpu_max="" cpu_min="" rapl_pl1="" rapl_pl2=""
        local epp="" platform_profile="" igpu_max="" igpu_slpc="" aspm=""
        local wifi_powersave=""
        while IFS='=' read -r key val; do
          case "$key" in
            turbo) turbo="$val" ;;
            governor) governor="$val" ;;
            cpu_max) cpu_max="$val" ;;
            cpu_min) cpu_min="$val" ;;
            rapl_pl1) rapl_pl1="$val" ;;
            rapl_pl2) rapl_pl2="$val" ;;
            epp) epp="$val" ;;
            platform_profile) platform_profile="$val" ;;
            igpu_max) igpu_max="$val" ;;
            igpu_slpc) igpu_slpc="$val" ;;
            aspm) aspm="$val" ;;
            wifi_powersave) wifi_powersave="$val" ;;
          esac
        done < "$STATE_DIR/saved-state"

        # Online all cores + restore uncore FIRST so freq/governor writes hit everything
        online_all_cores
        for f in /sys/devices/system/cpu/intel_uncore_frequency/*/max_freq_khz; do
          cat "$(dirname "$f")/initial_max_freq_khz" > "$f" 2>/dev/null || true
        done

        # Unlock freq range before restoring (avoids min > max errors)
        set_min_freq "$CPU_MIN"
        [ -n "$turbo" ] && set_turbo "$turbo"
        [ -n "$governor" ] && set_governor "$governor"
        [ -n "$cpu_max" ] && set_max_freq "$cpu_max"
        [ -n "$cpu_min" ] && set_min_freq "$cpu_min"
        [ -n "$rapl_pl1" ] && echo "$rapl_pl1" > "$RAPL/constraint_0_power_limit_uw" 2>/dev/null || true
        [ -n "$rapl_pl2" ] && echo "$rapl_pl2" > "$RAPL/constraint_1_power_limit_uw" 2>/dev/null || true
        [ -n "$epp" ] && set_epp "$epp"
        [ -n "$platform_profile" ] && set_platform_profile "$platform_profile"
        [ -n "$igpu_max" ] && set_igpu_max "$igpu_max"
        [ -n "$igpu_slpc" ] && set_igpu_slpc "$igpu_slpc"
        [ -n "$aspm" ] && set_aspm "$aspm"
        [ -n "$wifi_powersave" ] && set_wifi_powersave "$wifi_powersave"

        rm -f "$STATE_DIR/saved-state"
        echo -e "  ''${GREEN}State restored''${RESET}"
      fi
      # Restore per-device PCI runtime PM state
      if [ -f "$STATE_DIR/saved-pci-pm" ]; then
        while IFS='=' read -r dev val; do
          echo "$val" > "/sys/bus/pci/devices/$dev/power/control" 2>/dev/null || true
        done < "$STATE_DIR/saved-pci-pm"
        rm -f "$STATE_DIR/saved-pci-pm"
      fi
      # Restore services (bt/wifi sentinels)
      if [ -f "$STATE_DIR/bt-was-on" ]; then
        ${pkgs.bluez}/bin/bluetoothctl power on > /dev/null 2>&1 || true
        rm -f "$STATE_DIR/bt-was-on"
        echo -e "  ''${GREEN}Bluetooth restored''${RESET}"
      fi
      if [ -f "$STATE_DIR/wifi-was-on" ]; then
        ${pkgs.networkmanager}/bin/nmcli radio wifi on > /dev/null 2>&1 || true
        rm -f "$STATE_DIR/wifi-was-on"
        echo -e "  ''${GREEN}Wi-Fi restored''${RESET}"
      fi
    }

    # Apply all settings for a specific stretch level (0-9).
    # Self-contained: sets ALL levers to absolute values for that level.
    # Does NOT set brightness — caller handles that (calibrate vs stretch differ).
    # P-core hotplug: offline P-cores to eliminate leakage current (~1-3W savings)
    # cpu0 can never be offlined by the kernel, so we skip it. Only at level 9.
    offline_pcores() {
      for cpu in /sys/devices/system/cpu/cpu[0-9]*/online; do
        local num
        num=$(echo "$cpu" | grep -o 'cpu[0-9]*' | grep -o '[0-9]*')
        local max_freq
        max_freq=$(cat "/sys/devices/system/cpu/cpu$num/cpufreq/cpuinfo_max_freq" 2>/dev/null || echo 0)
        # P-cores have max freq > 1000 MHz (1000000 kHz)
        if [ "$max_freq" -gt 1000000 ] && [ "$num" != "0" ]; then
          echo 0 > "$cpu" 2>/dev/null || true
        fi
      done
    }

    online_all_cores() {
      for cpu in /sys/devices/system/cpu/cpu[0-9]*/online; do
        echo 1 > "$cpu" 2>/dev/null || true
      done
    }

    apply_round() {
      local round=$1
      # Re-LERP: the dial's max-save endpoint (round 9) now reaches only what
      # the OLD level 8 did. Pushing the continuous levers to the absolute floor
      # at level 9 caused race-to-idle losses (the slower CPU stayed busy long
      # enough that total energy went UP), so the efficiency loss outweighed the
      # time gained. Compress the interpolation so round 9 maps to old-round-8's
      # depth (~88%, not 100%): effective = round*8/9, pct = effective*100/9
      #   => pct = round * 800 / 81
      local pct=$((round * 800 / 81))

      # Bring all cores online first so freq/governor writes hit every core
      online_all_cores

      # Continuous levers: interpolate from performance (0%) to max-save (100%)
      local new_cpu new_rapl_uw new_igpu new_uncore
      new_cpu=$(calc_int "$CPU_MAX - $pct / 100 * ($CPU_MAX - $CPU_FLOOR)")
      new_rapl_uw=$(calc_int "28000000 - $pct / 100 * (28000000 - 1000000)")
      new_igpu=$(calc_int "''${GPU_MAX:-2250} - $pct / 100 * (''${GPU_MAX:-2250} - 100)")
      new_uncore=$(calc_int "3300000 - $pct / 100 * (3300000 - 400000)")

      set_min_freq "$CPU_FLOOR"
      set_max_freq "$new_cpu"
      set_rapl_uw "$new_rapl_uw"
      set_igpu_max "$new_igpu"
      # Cap uncore (ring/memory controller) frequency
      for f in /sys/devices/system/cpu/intel_uncore_frequency/*/max_freq_khz; do
        echo "$new_uncore" > "$f" 2>/dev/null || true
      done

      # Discrete levers: accumulate all flips up to this round
      local gov="performance" tv=0 ev="performance" pf="performance"
      local sv="base" av="default" wps="off" ppm="on"

      # Thresholds rescaled by the same re-LERP (old T now fires at ceil(T*9/8)),
      # so round 9 reproduces the old level-8 discrete state exactly.
      [ "$round" -ge 2 ] && ev="balance_performance" && wps="on" && ppm="auto"
      [ "$round" -ge 3 ] && gov="powersave" && av="powersave" && pf="balanced"
      [ "$round" -ge 4 ] && ev="balance_power" && pf="quiet"
      [ "$round" -ge 5 ] && tv=1 && sv="power_saving"
      [ "$round" -ge 6 ] && av="powersupersave"
      [ "$round" -ge 8 ] && ev="power"
      [ "$round" -ge 9 ] && ev="255"  # Max power saving EPP (more aggressive than "power"=192)

      set_governor "$gov"
      set_turbo "$tv"
      set_epp "$ev"
      set_platform_profile "$pf"
      set_igpu_slpc "$sv"
      set_aspm "$av"
      set_wifi_powersave "$wps"
      set_pci_pm "$ppm"

      # At level 9 (the re-LERPed max), offline P-cores to eliminate leakage
      # (~1-3W savings). E-cores and LP E-cores handle idle/light workloads fine
      if [ "$round" -ge 9 ]; then
        offline_pcores
      fi
    }

    recommend_externals() {
      local hints=()

      is_bt_on && hints+=("bluetoothctl power off  (~0.5W)")
      is_wifi_on && hints+=("nmcli radio wifi off  (~1-2W)")
      local bright
      bright=$(${pkgs.brightnessctl}/bin/brightnessctl -m 2>/dev/null | cut -d',' -f4 | tr -d '%')
      [ -n "$bright" ] && [ "$bright" -gt 20 ] && hints+=("Lower brightness to 20% or below  (~1-2W)")
      hints+=("Close browsers, Discord, IDEs")

      echo ""
      echo -e "  ''${YELLOW}Recommendations to stretch further:''${RESET}"
      for h in "''${hints[@]}"; do
        echo -e "    - $h"
      done
    }

    # Wait for RAPL to enforce the new power limit by watching energy_uj deltas.
    wait_rapl_settle() {
      [ ! -f "$RAPL/energy_uj" ] || [ ! -t 1 ] && return 0
      local pl1_w
      pl1_w=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.1f\", $(cat "$RAPL/constraint_0_power_limit_uw") / 1000000 }")
      local threshold
      threshold=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.1f\", $pl1_w * 1.3 }")
      local prev_uj
      prev_uj=$(cat "$RAPL/energy_uj")

      printf "    \033[2mwaiting for RAPL to settle...\033[0m"
      for _ in $(seq 1 6); do
        sleep 0.5
        local cur_uj pkg_w settled
        cur_uj=$(cat "$RAPL/energy_uj")
        pkg_w=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.1f\", ($cur_uj - $prev_uj) / 500000 }")
        prev_uj=$cur_uj
        settled=$(${pkgs.gawk}/bin/awk "BEGIN { print ($pkg_w <= $threshold) }")
        if [ "$settled" = "1" ]; then
          printf "\r\033[K"
          return 0
        fi
      done
      printf "\r\033[K"
    }

    show_status() {
      local settle="''${1:-}"

      local status percent energy
      status=$(bat_status)
      percent=$(bat_percent)
      energy=$(bat_energy_wh)

      local cur_freq cur_turbo cur_rapl cur_profile cur_brightness cur_governor cur_epp
      cur_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)
      cur_turbo=$(cat "$PSTATE/no_turbo" 2>/dev/null || echo "?")
      cur_rapl=$(calc_int "$(cat "$RAPL/constraint_0_power_limit_uw" 2>/dev/null || echo 0) / 1000000")
      cur_profile=$(cat "$PLATFORM_PROFILE" 2>/dev/null || echo "n/a")
      cur_brightness=$(${pkgs.brightnessctl}/bin/brightnessctl -m 2>/dev/null | cut -d',' -f4 | tr -d '%')
      cur_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
      cur_epp=$(get_epp)

      local cur_igpu_max cur_igpu_slpc cur_aspm
      cur_igpu_max=$(get_igpu_max)
      cur_igpu_slpc=$(get_igpu_slpc)
      cur_aspm=$(get_aspm)

      [ "$settle" = "settle" ] && wait_rapl_settle

      echo ""
      echo -e "''${BOLD}  Battery''${RESET}"
      local full_wh
      full_wh=$(calc "$(cat "$BAT/energy_full") / 1000000" 2)

      # Show charge limit if set
      local charge_limit=""
      if [ -f "$BAT/charge_control_end_threshold" ]; then
        charge_limit=$(cat "$BAT/charge_control_end_threshold" 2>/dev/null || echo "")
      fi

      if [ "$status" = "Discharging" ]; then
        echo -e "    ''${DIM}state:''${RESET}       $status"
        echo -e "    ''${DIM}level:''${RESET}       ''${energy} Wh / ''${full_wh} Wh (''${percent}%)"

        local watts hours sum count avg
        watts=$(bat_watts)
        hours="?"
        [ "$watts" != "0.0" ] && hours=$(calc "$energy / $watts")
        printf "    \033[2mdraw:\033[0m        %sW                    \n" "$watts"
        printf "    \033[2mestimate:\033[0m    ~%sh remaining          \n" "$hours"

        # Live-average over 5s if interactive terminal
        if [ -t 1 ]; then
          local raw_pw
          raw_pw=$(cat "$BAT/power_now" 2>/dev/null || echo 0)
          sum=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $raw_pw / 1000000 }")
          count=1
          for i in $(seq 1 9); do
            sleep 0.5
            local sample
            raw_pw=$(cat "$BAT/power_now" 2>/dev/null || echo 0)
            sample=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $raw_pw / 1000000 }")
            sum=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $sum + $sample }")
            count=$((count + 1))
            avg=$(calc "$sum / $count")
            hours="?"
            [ "$avg" != "0.0" ] && hours=$(calc "$energy / $avg")
            local elapsed
            elapsed=$(calc "$i * 0.5" 1)
            printf "\033[2A"
            printf "    \033[2mdraw:\033[0m        %sW  \033[2m(avg %ss)\033[0m          \n" "$avg" "$elapsed"
            printf "    \033[2mestimate:\033[0m    ~%sh remaining          \n" "$hours"
          done
        fi
      elif [ "$status" = "Charging" ]; then
        local watts charge_remaining hours_to_full
        watts=$(bat_watts)
        charge_remaining=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.2f\", $full_wh - $energy }")
        echo -e "    ''${DIM}state:''${RESET}       $status"
        echo -e "    ''${DIM}level:''${RESET}       ''${energy} Wh / ''${full_wh} Wh (''${percent}%)"
        if [ "$watts" != "0.0" ]; then
          hours_to_full=$(calc "$charge_remaining / $watts")
          echo -e "    ''${DIM}charge rate:''${RESET} ''${watts}W"
          echo -e "    ''${DIM}full in:''${RESET}     ~''${hours_to_full}h"
        fi
      else
        echo -e "    ''${DIM}state:''${RESET}       $status"
        echo -e "    ''${DIM}level:''${RESET}       ''${energy} Wh / ''${full_wh} Wh (''${percent}%)"
      fi

      if [ -n "$charge_limit" ] && [ "$charge_limit" != "100" ]; then
        echo -e "    ''${DIM}max charge:''${RESET}  ''${charge_limit}%"
      fi

      echo ""
      echo -e "''${BOLD}  CPU''${RESET}"
      echo -e "    ''${DIM}governor:''${RESET}    $cur_governor"
      echo -e "    ''${DIM}max freq:''${RESET}    $((cur_freq / 1000)) MHz"
      if [ "$cur_turbo" != "?" ]; then
        echo -e "    ''${DIM}turbo:''${RESET}       $([ "$cur_turbo" = "0" ] && echo "on" || echo "off")"
      fi
      echo -e "    ''${DIM}RAPL PL1:''${RESET}    ''${cur_rapl}W"
      echo -e "    ''${DIM}EPP:''${RESET}         $cur_epp"
      echo -e "    ''${DIM}profile:''${RESET}     $cur_profile"

      echo ""
      echo -e "''${BOLD}  GPU''${RESET}"
      if [ -n "$cur_igpu_max" ]; then
        echo -e "    ''${DIM}max freq:''${RESET}    ''${cur_igpu_max} MHz"
      else
        echo -e "    ''${DIM}max freq:''${RESET}    n/a"
      fi
      echo -e "    ''${DIM}SLPC:''${RESET}        ''${cur_igpu_slpc:-n/a}"

      local cur_wifi_ps cur_pci_pm
      cur_wifi_ps=$(get_wifi_powersave)
      cur_pci_pm=$(get_pci_pm)

      echo ""
      echo -e "''${BOLD}  System''${RESET}"
      echo -e "    ''${DIM}ASPM:''${RESET}        ''${cur_aspm:-n/a}"
      echo -e "    ''${DIM}wifi ps:''${RESET}     ''${cur_wifi_ps:-n/a}"
      echo -e "    ''${DIM}PCI pm:''${RESET}      $cur_pci_pm"
      echo -e "    ''${DIM}brightness:''${RESET}  ''${cur_brightness:-?}%"
      echo ""
    }

    # ── Apply a level (0-9) with save/restore logic ──
    apply_level() {
      local level=$1

      # Persist current level so unprivileged tools (e.g. waybar) can read it
      echo "$level" > "$STATE_DIR/current-level"
      chmod 644 "$STATE_DIR/current-level"
      echo "$level" > "$DATA_DIR/last-level"
      # Save as user's persistent preference (only for manual CLI calls)
      if [ "$_AUTO" = "0" ]; then
        echo "$level" > "$DATA_DIR/user-level"
        # Signal the watchdog that the user manually overrode
        # chown to the calling user so the watchdog (user service) can delete it
        touch "$STATE_DIR/manual-override"
        [ -n "''${SUDO_UID:-}" ] && chown "$SUDO_UID" "$STATE_DIR/manual-override"
      fi

      if [ "$level" = "0" ]; then
        restore_state
      else
        save_state
      fi

      apply_round "$level"

      echo -e "''${CYAN}Applied L$level ($((level * 100 / 9))%)''${RESET}"

      if [ "$level" -ge 9 ]; then
        recommend_externals
      fi
    }

    # ── Calibrate: benchmark all 10 levels under full CPU load ──
    run_calibrate() {
      if [ "$(bat_status)" != "Discharging" ]; then
        echo -e "''${YELLOW}Unplug charger before calibrating — AC power skews measurements.''${RESET}"
        return 1
      fi

      echo -e "''${BOLD}Calibrating power levels under full CPU load (~3 min)...''${RESET}"
      echo -e "  ''${DIM}10 levels x 20s each. Do not interrupt.''${RESET}"
      echo ""

      save_state

      # Start CPU stress on all cores
      local stress_pids=""
      for _ in $(seq 1 $(nproc)); do
        yes > /dev/null 2>&1 &
        stress_pids="$stress_pids $!"
      done

      local cal_results=""

      for round in $(seq 0 9); do
        local pct=$((round * 100 / 9))

        apply_round "$round"

        # 5s settle
        sleep 5

        # 15s measurement (30 samples)
        local sum count avg
        sum=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $(read_power_uw) / 1000000 }")
        count=1
        for _ in $(seq 1 29); do
          sleep 0.5
          local sample
          sample=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $(read_power_uw) / 1000000 }")
          sum=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $sum + $sample }")
          count=$((count + 1))
        done
        avg=$(calc "$sum / $count")

        printf "  R%-2d (%3d%%)  %sW\n" "$round" "$pct" "$avg"
        cal_results="''${cal_results}$round:$avg
"
      done

      # Kill stress
      kill $stress_pids 2>/dev/null || true
      wait 2>/dev/null || true

      # Restore to original state
      restore_state

      # Post-process: -0.5W idle bonus + monotonic enforcement (each ≤ prev - 1W)
      local adjusted
      adjusted=$(echo "$cal_results" | ${pkgs.gawk}/bin/awk -F: '/^[0-9]/ {
        # Cumulative idle-only discrete levers per round (~0.2W each), tracking
        # the re-LERPed thresholds:
        # R2:+EPP  R3:+gov,ASPM  R4:+EPP,profile  R5:+SLPC  R6:+ASPM  R8:+EPP
        split("0,0,1,3,5,6,7,7,8,8", lc, ",")
        raw = $2 - lc[$1 + 1] * 0.2
        if (!started) { adj = raw; started = 1 }
        else {
          ceil = prev - 1
          adj = (raw < ceil) ? raw : ceil
        }
        prev = adj
        printf "%d:%.1f\n", $1, adj
      }')

      echo ""
      echo -e "  ''${DIM}Adjusted (idle bonus -0.5W, monotonic -1W/level):''${RESET}"
      echo "$adjusted" | ${pkgs.gawk}/bin/awk -F: '{ printf "  R%-2d  %.1fW\n", $1, $2 }'

      # Save calibration
      {
        echo "# power-mode calibration"
        echo "# date=$(date +%Y-%m-%d)"
        echo "# cpu_max=$CPU_MAX"
        echo "$adjusted"
      } > "$DATA_DIR/calibration"

      echo ""
      echo -e "  ''${GREEN}Calibration saved. Stretch mode is now available.''${RESET}"
    }

    # ── Stretch: lookup calibration table, jump to the right level ──
    profile_stretch() {
      local target_hours=$1

      if [ "$(bat_status)" = "Charging" ]; then
        echo -e "''${GREEN}Battery is charging — no need to stretch.''${RESET}"
        show_status
        return 0
      fi

      if [ ! -f "$DATA_DIR/calibration" ]; then
        echo -e "''${YELLOW}Stretch requires calibration data. Run once to profile your system:''${RESET}"
        echo ""
        echo "    power-mode calibrate"
        echo ""
        echo -e "  This benchmarks power draw at each level under load (~3 min)."
        return 1
      fi

      local energy percent target_watts
      energy=$(bat_energy_wh)
      percent=$(bat_percent)
      target_watts=$(calc "$energy / $target_hours" 2)

      local cal_date
      cal_date=$(grep "^# date=" "$DATA_DIR/calibration" | cut -d= -f2)

      echo -e "''${BOLD}Stretch mode: target ''${target_hours}h''${RESET}"
      echo -e "  Battery: ''${energy} Wh (''${percent}%)"
      echo -e "  Budget:  ''${target_watts}W  ''${DIM}(calibrated ''${cal_date})''${RESET}"
      echo ""

      # Find best round from calibration (first where watts <= budget)
      local best_round=-1 best_watts=""
      while IFS=: read -r round watts; do
        case "$round" in "#"*|"") continue ;; esac
        if ${pkgs.gawk}/bin/awk "BEGIN { exit !($watts <= $target_watts) }"; then
          best_round=$round
          best_watts=$watts
          break
        fi
      done < "$DATA_DIR/calibration"

      save_state

      if [ "$best_round" = "-1" ]; then
        echo -e "  ''${DIM}No level meets budget under load — applying maximum (R9)''${RESET}"
        apply_round 9
      else
        echo -e "  Applying level $best_round ($((best_round * 100 / 9))%) — calibrated: ''${best_watts}W under load"
        apply_round "$best_round"
      fi

      # Quick 5s verification at actual current load
      echo ""
      local measured
      if [ -t 1 ]; then
        local sum count avg
        sum=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $(read_power_uw) / 1000000 }")
        count=1
        printf "  Verifying: %sW  \033[2m(sampling)\033[0m              \n" "$sum"
        for i in $(seq 1 9); do
          sleep 0.5
          local sample
          sample=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $(read_power_uw) / 1000000 }")
          sum=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $sum + $sample }")
          count=$((count + 1))
          avg=$(calc "$sum / $count")
          printf "\033[1A"
          printf "  Verifying: %sW  \033[2m(avg %ss)\033[0m              \n" "$avg" "$(calc "$i * 0.5" 1)"
        done
        measured="$avg"
      else
        sleep 5
        measured=$(bat_watts)
      fi

      local hours
      hours=$(calc "$energy / $measured")

      if ${pkgs.gawk}/bin/awk "BEGIN { exit !($measured <= $target_watts) }"; then
        echo -e "  ''${GREEN}Verified: ''${measured}W — ~''${hours}h (target: ''${target_hours}h)''${RESET}"
      else
        echo -e "  ''${YELLOW}Verified: ''${measured}W — realistic: ~''${hours}h (target was ''${target_hours}h)''${RESET}"
        recommend_externals
      fi
    }

    usage() {
      echo ""
      echo -e "''${BOLD}power-mode''${RESET} — power profile manager"
      echo ""
      echo -e "  ''${BOLD}Usage:''${RESET}"
      echo "    power-mode <profile>"
      echo "    power-mode stretch <hours>"
      echo "    power-mode status"
      echo ""
      echo -e "  ''${BOLD}Levels (0-9):''${RESET}"
      echo "    0    Full speed, turbo on, 28W"
      echo "    3    Moderate savings, turbo on, ~22W"
      echo "    5    Turbo off, ~15W"
      echo "    8    Deep savings, ~7W"
      echo "    9    Maximum: P-cores offline, EPP max, ~4W"
      echo "    1-9  Any level for fine-grained control"
      echo ""
      echo -e "  ''${BOLD}Stretch mode:''${RESET}"
      echo "    calibrate         Benchmark all levels under load (~3 min, run once)"
      echo "    stretch <hours>   Apply optimal level to last <hours>"
      echo ""
      echo -e "  ''${BOLD}Battery health:''${RESET}"
      echo "    charge-limit <percent>  Set max charge level (20-100)"
      echo "    charge-limit            Show current charge limit"
      echo ""
      echo -e "  ''${BOLD}Examples:''${RESET}"
      echo "    power-mode calibrate"
      echo "    power-mode stretch 10"
      echo "    power-mode 4"
      echo "    power-mode charge-limit 80"
      echo "    power-mode status"
      echo ""
    }

    # --auto flag: called by watchdog, don't overwrite persistent user-level
    _AUTO=0
    if [ "''${1:-}" = "--auto" ]; then
      _AUTO=1
      shift
    fi

    case "''${1:-}" in
      [0-9])       apply_level "$1"; show_status settle ;;
      calibrate) run_calibrate ;;
      stretch)
        if [ -z "''${2:-}" ]; then
          echo "Usage: power-mode stretch <hours>"
          exit 1
        fi
        profile_stretch "$2"
        show_status settle
        ;;
      charge-limit)
        if [ -n "''${2:-}" ]; then
          set_charge_limit "$2"
        else
          cl=$(get_charge_limit)
          if [ -n "$cl" ]; then
            echo -e "''${BOLD}Charge limit:''${RESET} ''${cl}%"
          else
            echo -e "''${YELLOW}Battery does not support charge limit.''${RESET}"
          fi
        fi
        ;;
      status) show_status ;;
      *) usage ;;
    esac
  '';

  battery-watchdog = pkgs.writeShellScriptBin "battery-watchdog" ''
    BAT=""
    for b in /sys/class/power_supply/BAT*; do
      [ -f "$b/energy_now" ] && BAT="$b" && break
    done
    [ -z "$BAT" ] && exit 0

    PERCENT=$(cat "$BAT/capacity")
    STATUS=$(cat "$BAT/status")
    STATE_DIR="/tmp/power-mode"
    mkdir -p "$STATE_DIR"
    CURRENT_LEVEL=0
    [ -f "$STATE_DIR/current-level" ] && CURRENT_LEVEL=$(cat "$STATE_DIR/current-level")

    # User's persistent manual choice (survives reboot)
    USER_LEVEL=0
    [ -f /var/lib/power-mode/user-level ] && USER_LEVEL=$(cat /var/lib/power-mode/user-level)

    calc() {
      ${pkgs.gawk}/bin/awk "BEGIN { printf \"%.''${2:-1}f\", $1 }"
    }

    # Send or replace a notification, averaging power over 5s.
    # $1=urgency $2=title $3=profile_name
    notify_with_estimate() {
      local urgency="$1" title="$2" profile="$3"
      local energy watts hours notif_id

      energy=$(calc "$(cat "$BAT/energy_now") / 1000000" 2)
      watts=$(calc "$(read_power_uw) / 1000000")
      hours="?"
      [ "$watts" != "0.0" ] && hours=$(calc "$energy / $watts")

      notif_id=$(${pkgs.libnotify}/bin/notify-send \
        -u "$urgency" \
        -t 0 \
        -p \
        "$title" \
        "''${PERCENT}% — $profile\n''${energy} Wh at ''${watts}W\n~''${hours}h remaining")

      local sum count avg
      sum=$(calc "$(read_power_uw) / 1000000" 4)
      count=1
      for _ in $(seq 1 9); do
        sleep 0.5
        local sample
        sample=$(calc "$(read_power_uw) / 1000000" 4)
        sum=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $sum + $sample }")
        count=$((count + 1))
        avg=$(calc "$sum / $count")
        hours="?"
        [ "$avg" != "0.0" ] && hours=$(calc "$energy / $avg")
        notif_id=$(${pkgs.libnotify}/bin/notify-send \
          -u "$urgency" \
          -t 0 \
          -r "$notif_id" \
          -p \
          "$title" \
          "''${PERCENT}% — $profile\n''${energy} Wh at ''${avg}W avg\n~''${hours}h remaining")
      done
    }

    # Clear manual override on charging state changes (plug/unplug)
    # Use per-user file to avoid SDDM ownership conflicts
    LAST_STATUS=""
    STATUS_FILE="$STATE_DIR/last-status-$(id -u)"
    [ -f "$STATUS_FILE" ] && LAST_STATUS=$(cat "$STATUS_FILE")
    if [ "$STATUS" != "$LAST_STATUS" ] && [ -n "$LAST_STATUS" ]; then
      rm -f "$STATE_DIR/manual-override" "$STATE_DIR/overridden-target"
    fi
    echo "$STATUS" > "$STATUS_FILE"

    # Determine target level: user's choice, bumped up for low battery (max 9)
    target=$USER_LEVEL
    if [ "$STATUS" = "Discharging" ]; then
      [ "$PERCENT" -le 75 ] && [ "$target" -lt 8 ] && target=8
      [ "$PERCENT" -le 25 ] && [ "$target" -lt 9 ] && target=9
    fi

    # Manual override: user ran power-mode manually, back off until a NEW threshold
    # On first poll after override, record what auto-target was being suppressed
    if [ -f "$STATE_DIR/manual-override" ]; then
      echo "$target" > "$STATE_DIR/overridden-target"
      rm -f "$STATE_DIR/manual-override"
    fi
    if [ -f "$STATE_DIR/overridden-target" ]; then
      saved_target=$(cat "$STATE_DIR/overridden-target")
      if [ "$target" -gt "$saved_target" ]; then
        # A higher threshold kicked in (e.g., crossed ≤25%) — clear and apply
        rm -f "$STATE_DIR/overridden-target"
      else
        # Same or lower threshold — respect the user's override
        exit 0
      fi
    fi

    # Only act when current level differs from target
    if [ "$CURRENT_LEVEL" != "$target" ]; then
      ${power-mode}/bin/power-mode --auto "$target" > /dev/null 2>&1

      if [ "$STATUS" = "Discharging" ] && [ "$target" -ge 9 ] && [ "$target" -gt "$USER_LEVEL" ]; then
        notify_with_estimate critical "Battery Low" "level 9\nConsider lowering brightness"
      elif [ "$STATUS" = "Discharging" ] && [ "$target" -ge 8 ] && [ "$target" -gt "$USER_LEVEL" ]; then
        ${pkgs.libnotify}/bin/notify-send -u low -t 5000 "Battery ≤75%" "Switched to level 8"
      elif [ "$STATUS" = "Charging" ] && [ "$target" -le "$USER_LEVEL" ]; then
        ${pkgs.libnotify}/bin/notify-send -u low -t 5000 "Charging" "Restored to level $target"
      fi
    fi
  '';

  # powertop --auto-tune (enabled below) writes power/control=auto to *every* USB
  # device, including the Bluetooth controller, overriding the
  # `btusb enable_autosuspend=0` modprobe option set per-host. The radio then
  # autosuspends after ~1s of idle; on the next BLE reconnect the bond/link state
  # desyncs and HID-over-GATT attribute reads fail (ATT 0x0E) in a tight
  # connect/disconnect loop that only a full forget+re-pair clears. Re-pin every
  # USB Bluetooth controller (class e0/subclass 01/protocol 01) to `on` so it
  # never autosuspends. Matched by class so it is host- and dongle-agnostic.
  bt-no-autosuspend = pkgs.writeShellScript "bt-no-autosuspend" ''
    for dev in /sys/bus/usb/devices/*; do
      [ -r "$dev/bDeviceClass" ] || continue
      [ "$(cat "$dev/bDeviceClass")" = "e0" ] || continue
      [ "$(cat "$dev/bDeviceSubClass" 2>/dev/null)" = "01" ] || continue
      [ "$(cat "$dev/bDeviceProtocol" 2>/dev/null)" = "01" ] || continue
      echo on > "$dev/power/control" 2>/dev/null || true
    done
  '';

  # Same powertop fallout, different victim: USB-audio gadgets with flaky
  # firmware (e.g. the Hollyland "Wireless microphone" 3547:0007) cannot survive
  # their *parent root hub* autosuspending. powertop --auto-tune sets the root
  # hub's power/control=auto (delay 0); the device then full-disconnects and
  # re-enumerates every 2-4 min (malformed descriptor, "cannot set freq 48000 to
  # ep 0x81"), so any capture stream dies. The device's own power/control was
  # already `on` — pinning the *bus* is what stops it. Find every attached USB
  # audio device (bInterfaceClass 01) and pin both it and its root hub to `on`.
  # Class-matched so it is device- and port-agnostic. See bt-no-autosuspend.
  usb-audio-keep-bus-awake = pkgs.writeShellScript "usb-audio-keep-bus-awake" ''
    for ifc in /sys/bus/usb/devices/*:*/bInterfaceClass; do
      [ "$(cat "$ifc" 2>/dev/null)" = "01" ] || continue
      ifn="$(basename "$(dirname "$ifc")")"   # interface dir, e.g. "3-2:1.0"
      dev="''${ifn%%:*}"                       # device, e.g. "3-2"
      bus="''${dev%%-*}"                       # e.g. "3" -> usb3
      echo on > "/sys/bus/usb/devices/$dev/power/control" 2>/dev/null || true
      echo on > "/sys/bus/usb/devices/usb$bus/power/control" 2>/dev/null || true
    done
  '';

  # Same powertop fallout, applied to USB HID input devices. When the Corne is
  # cabled (USB central, 1d50:615e) powertop --auto-tune sets its power/control
  # =auto with autosuspend_delay_ms=1000, so the keyboard suspends after 1s idle.
  # It also comes up power/wakeup=disabled, so it *cannot* USB-remote-wake — the
  # next keypress on a suspended device isn't signalled until the host resumes it
  # (~1s), which the user feels as "keyboard sleeps after a few seconds, ~1s to
  # recover" and can drop the first keystrokes. Pin every USB HID interface's
  # parent device to `on`; a pinned child also blocks its parent hub from
  # autosuspending, so the device-level pin is sufficient. Matched on HID class
  # 03 (the Corne HID interface is class 03 / protocol 00, NOT boot-keyboard
  # protocol 01, so a protocol match would miss it) — device- and port-agnostic.
  # See usb-audio-keep-bus-awake / bt-no-autosuspend.
  usb-hid-keep-awake = pkgs.writeShellScript "usb-hid-keep-awake" ''
    for ifc in /sys/bus/usb/devices/*:*/bInterfaceClass; do
      [ "$(cat "$ifc" 2>/dev/null)" = "03" ] || continue
      ifn="$(basename "$(dirname "$ifc")")"   # interface dir, e.g. "3-4.1:1.2"
      dev="''${ifn%%:*}"                       # device, e.g. "3-4.1"
      echo on > "/sys/bus/usb/devices/$dev/power/control" 2>/dev/null || true
    done
  '';

in
{
  powerManagement.powertop.enable = true;

  # Counteract powertop's blanket USB autosuspend on the Bluetooth radio.
  # A *separate* oneshot ordered `after powertop.service` + `wantedBy
  # multi-user.target` deadlocks: NixOS's powertop.service is itself
  # `After=multi-user.target`, so that forms an ordering cycle
  # (bt-svc -> powertop -> multi-user.target -> bt-svc) and systemd silently
  # deletes our job to break it — the re-pin never runs and the loop returns.
  # Instead hang the re-pin off powertop's own oneshot as ExecStartPost: it runs
  # immediately after `--auto-tune` completes, introduces no new unit anchored to
  # multi-user.target, so a cycle is impossible. Also re-applied on resume since
  # suspend/resume re-enumerates USB power state. See bt-no-autosuspend.
  systemd.services.powertop.serviceConfig.ExecStartPost = [
    "${bt-no-autosuspend}"
    "${usb-audio-keep-bus-awake}"
    "${usb-hid-keep-awake}"
  ];
  powerManagement.resumeCommands = ''
    ${bt-no-autosuspend}
    ${usb-audio-keep-bus-awake}
    ${usb-hid-keep-awake}
  '';

  # ExecStartPost only covers devices present when powertop runs (boot) and
  # resume. For a USB-audio device hot-plugged later, powertop has already set
  # its root hub to `auto` and never re-runs — so re-pin the bus on hotplug too.
  # Matched on the audio interface so it stays device-agnostic.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ENV{INTERFACE}=="1/*", RUN+="${usb-audio-keep-bus-awake}"
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_interface", ENV{INTERFACE}=="3/*", RUN+="${usb-hid-keep-awake}"
  '';

  # Allow power-mode to run as root without password for wheel users
  # SETENV needed so sudo doesn't strip env in some contexts
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        { command = "${power-mode}/bin/power-mode"; options = [ "NOPASSWD" "SETENV" ]; }
      ];
    }
  ];

  # Allow sudo without a tty (needed for systemd user services calling power-mode)
  # Longer timestamp + !tty_tickets so a single `sudo -v` primes credentials
  # across all of the user's shells (Claude Code Bash tool, terminal panes,
  # background scripts) for an hour — saves password prompts during debug
  # sessions involving lots of sudo (kernel tracing, sysfs writes, etc.)
  security.sudo.extraConfig = ''
    Defaults !requiretty
    Defaults timestamp_timeout=60
    Defaults !tty_tickets
  '';

  environment.systemPackages = [
    power-mode
    pkgs.brightnessctl
  ];

  # Battery watchdog: user service so it has D-Bus access for notifications
  systemd.user.services.battery-watchdog = {
    description = "Auto-switch power profile on low battery";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${battery-watchdog}/bin/battery-watchdog";
    };
    unitConfig = {
      StartLimitIntervalSec = 0; # Disable rate limiting for 1s polling
    };
  };

  # Auto-bump on battery % disabled — Jorge wants power level to stay where he
  # sets it manually. Service+timer definitions kept so they can be re-enabled
  # by adding `wantedBy = [ "timers.target" ];` back if desired.
  systemd.user.timers.battery-watchdog = {
    description = "Poll battery level every 1s";
    timerConfig = {
      OnBootSec = "1s";
      OnUnitActiveSec = "1s";
      AccuracySec = "1s"; # Override default 1min batching
    };
  };
}
