{ config, pkgs, lib, ... }:

let
  power-mode = pkgs.writeShellScriptBin "power-mode" ''
    set -euo pipefail

    # Self-elevate to root — sysfs and RAPL require it
    if [ "$(id -u)" != "0" ]; then
      exec sudo "$(readlink -f "$0")" "$@"
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
      raw=$(cat "$BAT/power_now")
      if [ "$raw" = "0" ]; then
        echo "0.0"
      else
        calc "$raw / 1000000"
      fi
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

    set_rapl() {
      if [ -d "$RAPL" ]; then
        local uw=$(($1 * 1000000))
        echo "$uw" > "$RAPL/constraint_0_power_limit_uw"
        echo "$((uw + 2000000))" > "$RAPL/constraint_1_power_limit_uw"
      fi
    }

    # RAPL with raw microwatts (for stretch interpolation)
    set_rapl_uw() {
      if [ -d "$RAPL" ]; then
        echo "$1" > "$RAPL/constraint_0_power_limit_uw"
        echo "$(($1 + 2000000))" > "$RAPL/constraint_1_power_limit_uw"
      fi
    }

    set_brightness() {
      ${pkgs.brightnessctl}/bin/brightnessctl set "''${1}%" > /dev/null 2>&1 || true
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
        echo "brightness=$(${pkgs.brightnessctl}/bin/brightnessctl -m 2>/dev/null | cut -d',' -f4 | tr -d '%')"
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
        local epp="" platform_profile="" brightness="" igpu_max="" igpu_slpc="" aspm=""
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
            brightness) brightness="$val" ;;
            igpu_max) igpu_max="$val" ;;
            igpu_slpc) igpu_slpc="$val" ;;
            aspm) aspm="$val" ;;
            wifi_powersave) wifi_powersave="$val" ;;
          esac
        done < "$STATE_DIR/saved-state"

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
        [ -n "$brightness" ] && set_brightness "$brightness"
        [ -n "$igpu_max" ] && set_igpu_max "$igpu_max"
        [ -n "$igpu_slpc" ] && set_igpu_slpc "$igpu_slpc"
        [ -n "$aspm" ] && set_aspm "$aspm"
        [ -n "$wifi_powersave" ] && set_wifi_powersave "$wifi_powersave"

        # Bring all cores back online before restoring freq/governor
        online_all_cores

        rm -f "$STATE_DIR/saved-state"
        rm -f "$STATE_DIR/saved-brightness"
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

    # Apply all settings for a specific stretch level (0-10).
    # Self-contained: sets ALL levers to absolute values for that level.
    # Does NOT set brightness — caller handles that (calibrate vs stretch differ).
    # P-core hotplug: offline P-cores to eliminate leakage current (~1-3W savings)
    # cpu0 can never be offlined by the kernel, so we skip it
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
      local pct=$((round * 10))

      # Bring all cores online first so freq/governor writes hit every core
      online_all_cores

      # Continuous levers: interpolate from performance (0%) to max-save (100%)
      local new_cpu new_rapl_uw new_igpu
      new_cpu=$(calc_int "$CPU_MAX - $pct / 100 * ($CPU_MAX - $CPU_FLOOR)")
      new_rapl_uw=$(calc_int "28000000 - $pct / 100 * (28000000 - 1000000)")
      new_igpu=$(calc_int "''${GPU_MAX:-2250} - $pct / 100 * (''${GPU_MAX:-2250} - 100)")

      set_min_freq "$CPU_FLOOR"
      set_max_freq "$new_cpu"
      set_rapl_uw "$new_rapl_uw"
      set_igpu_max "$new_igpu"

      # Discrete levers: accumulate all flips up to this round
      local gov="performance" tv=0 ev="performance" pf="performance"
      local sv="base" av="default" wps="off" ppm="on"

      [ "$round" -ge 1 ] && ev="balance_performance" && wps="on" && ppm="auto"
      [ "$round" -ge 2 ] && gov="powersave" && av="powersave" && pf="balanced"
      [ "$round" -ge 3 ] && ev="balance_power" && pf="quiet"
      [ "$round" -ge 4 ] && tv=1 && sv="power_saving"
      [ "$round" -ge 5 ] && av="powersupersave"
      [ "$round" -ge 7 ] && ev="power"

      set_governor "$gov"
      set_turbo "$tv"
      set_epp "$ev"
      set_platform_profile "$pf"
      set_igpu_slpc "$sv"
      set_aspm "$av"
      set_wifi_powersave "$wps"
      set_pci_pm "$ppm"

      # At level >= 8, offline P-cores to eliminate leakage (~1-3W savings)
      # E-cores and LP E-cores handle idle/light workloads fine
      if [ "$round" -ge 8 ]; then
        offline_pcores
      fi
    }

    # Brightness value for a given round (50% base → 5% at round 10)
    round_brightness() {
      calc_int "50 - $1 * 10 / 100 * (50 - 5)"
    }

    recommend_externals() {
      local urgency="''${1:-normal}"
      local hints=()

      if [ "$urgency" = "tight" ]; then
        is_bt_on && hints+=("bluetoothctl power off  (~0.5W)")
        is_wifi_on && hints+=("nmcli radio wifi off  (~1-2W)")
      fi
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
          sum=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $(cat "$BAT/power_now") / 1000000 }")
          count=1
          for i in $(seq 1 9); do
            sleep 0.5
            local sample
            sample=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $(cat "$BAT/power_now") / 1000000 }")
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

    # ── Apply a level (0-10) with save/restore logic ──
    level_name() {
      case "$1" in
        0) echo "performance" ;;
        2) echo "balanced" ;;
        4) echo "powersave" ;;
        10) echo "emergency" ;;
        *) echo "" ;;
      esac
    }

    apply_level() {
      local level=$1
      local name
      name=$(level_name "$level")

      # Persist current level so unprivileged tools (e.g. waybar) can read it
      echo "$level" > "$STATE_DIR/current-level"
      chmod 644 "$STATE_DIR/current-level"
      echo "$level" > "$DATA_DIR/last-level"
      # Save as user's persistent preference (only for manual CLI calls)
      if [ "$_AUTO" = "0" ]; then
        echo "$level" > "$DATA_DIR/user-level"
      fi

      if [ "$level" = "0" ]; then
        restore_state
        rm -f "$STATE_DIR/saved-brightness"
      else
        save_state
      fi

      apply_round "$level"

      # Brightness: only adjust at emergency (level 10), restore when dropping below
      if [ "$level" != "0" ]; then
        local cur_bright
        cur_bright=$(${pkgs.brightnessctl}/bin/brightnessctl -m 2>/dev/null | cut -d',' -f4 | tr -d '%')
        cur_bright="''${cur_bright:-50}"

        if [ "$level" -ge 10 ]; then
          # Save user's brightness before we lower it
          local saved_bright=""
          [ -f "$STATE_DIR/saved-brightness" ] && saved_bright=$(cat "$STATE_DIR/saved-brightness")
          if [ -z "$saved_bright" ] || [ "$cur_bright" -gt "$saved_bright" ]; then
            echo "$cur_bright" > "$STATE_DIR/saved-brightness"
          fi
          # Apply level brightness (only lower, never raise)
          local bright
          bright=$(round_brightness "$level")
          if [ "$cur_bright" -gt "$bright" ]; then
            set_brightness "$bright"
          fi
        else
          # Level 1-9: restore brightness if emergency previously lowered it
          if [ -f "$STATE_DIR/saved-brightness" ]; then
            set_brightness "$(cat "$STATE_DIR/saved-brightness")"
            rm -f "$STATE_DIR/saved-brightness"
          fi
        fi
      fi

      if [ -n "$name" ]; then
        echo -e "''${CYAN}Applied level $level — $name''${RESET}"
      else
        echo -e "''${CYAN}Applied level $level ($((level * 10))%)''${RESET}"
      fi

      if [ "$level" = "10" ]; then
        recommend_externals tight
      fi
    }

    # ── Calibrate: benchmark all 11 levels under full CPU load ──
    run_calibrate() {
      if [ "$(bat_status)" != "Discharging" ]; then
        echo -e "''${YELLOW}Unplug charger before calibrating — AC power skews measurements.''${RESET}"
        return 1
      fi

      echo -e "''${BOLD}Calibrating power levels under full CPU load (~4 min)...''${RESET}"
      echo -e "  ''${DIM}11 levels x 20s each. Do not interrupt.''${RESET}"
      echo ""

      save_state

      # Start CPU stress on all cores
      local stress_pids=""
      for _ in $(seq 1 $(nproc)); do
        yes > /dev/null 2>&1 &
        stress_pids="$stress_pids $!"
      done

      local cal_results=""

      for round in $(seq 0 10); do
        local pct=$((round * 10))
        local bright
        bright=$(round_brightness "$round")

        apply_round "$round"
        set_brightness "$bright"

        # 5s settle
        sleep 5

        # 15s measurement (30 samples)
        local sum count avg
        sum=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $(cat "$BAT/power_now") / 1000000 }")
        count=1
        for _ in $(seq 1 29); do
          sleep 0.5
          local sample
          sample=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $(cat "$BAT/power_now") / 1000000 }")
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
        # Cumulative idle-only discrete levers per round (~0.2W each):
        # R1:+EPP  R2:+gov,ASPM  R3:+EPP,profile  R4:+SLPC  R5:+ASPM  R7:+EPP
        split("0,1,3,5,6,7,7,8,8,8,8", lc, ",")
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
        echo -e "  This benchmarks power draw at each level under load (~4 min)."
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

      local cur_bright
      cur_bright=$(${pkgs.brightnessctl}/bin/brightnessctl -m 2>/dev/null | cut -d',' -f4 | tr -d '%')
      cur_bright="''${cur_bright:-50}"
      local effective_level

      if [ "$best_round" = "-1" ]; then
        echo -e "  ''${DIM}No level meets budget under load — applying maximum (R10)''${RESET}"
        apply_round 10
        effective_level=10
      else
        echo -e "  Applying level $best_round ($((best_round * 10))%) — calibrated: ''${best_watts}W under load"
        apply_round "$best_round"
        effective_level=$best_round
      fi

      # Brightness: only adjust at level >= 7
      if [ "$effective_level" -ge 7 ]; then
        if [ -z "$(cat "$STATE_DIR/saved-brightness" 2>/dev/null)" ] || [ "$cur_bright" -gt "$(cat "$STATE_DIR/saved-brightness" 2>/dev/null || echo 0)" ]; then
          echo "$cur_bright" > "$STATE_DIR/saved-brightness"
        fi
        local bright
        bright=$(round_brightness "$effective_level")
        if [ "$cur_bright" -gt "$bright" ]; then
          set_brightness "$bright"
        fi
      fi

      # Quick 5s verification at actual current load
      echo ""
      local measured
      if [ -t 1 ]; then
        local sum count avg
        sum=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $(cat "$BAT/power_now") / 1000000 }")
        count=1
        printf "  Verifying: %sW  \033[2m(sampling)\033[0m              \n" "$sum"
        for i in $(seq 1 9); do
          sleep 0.5
          local sample
          sample=$(${pkgs.gawk}/bin/awk "BEGIN { printf \"%.4f\", $(cat "$BAT/power_now") / 1000000 }")
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
        recommend_externals tight
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
      echo -e "  ''${BOLD}Levels (0-10):''${RESET}"
      echo "    0  performance   Full speed, turbo on, 28W"
      echo "    2  balanced      Moderate savings, turbo on, 20W"
      echo "    4  powersave     Turbo off, 10W, 32% brightness"
      echo "    10 emergency     800 MHz, 4W, 5% brightness"
      echo "    1-10             Any level for fine-grained control"
      echo ""
      echo -e "  ''${BOLD}Stretch mode:''${RESET}"
      echo "    calibrate         Benchmark all levels under load (~4 min, run once)"
      echo "    stretch <hours>   Apply optimal level to last <hours>"
      echo ""
      echo -e "  ''${BOLD}Battery health:''${RESET}"
      echo "    charge-limit <percent>  Set max charge level (20-100)"
      echo "    charge-limit            Show current charge limit"
      echo ""
      echo -e "  ''${BOLD}Examples:''${RESET}"
      echo "    power-mode calibrate"
      echo "    power-mode stretch 10"
      echo "    power-mode powersave"
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
      performance) apply_level 0;  show_status settle ;;
      balanced)    apply_level 2;  show_status settle ;;
      powersave)   apply_level 4;  show_status settle ;;
      emergency)   apply_level 10; show_status settle ;;
      [0-9]|10)    apply_level "$1"; show_status settle ;;
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
          local cl
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
      watts=$(calc "$(cat "$BAT/power_now") / 1000000")
      hours="?"
      [ "$watts" != "0.0" ] && hours=$(calc "$energy / $watts")

      notif_id=$(${pkgs.libnotify}/bin/notify-send \
        -u "$urgency" \
        -t 0 \
        -p \
        "$title" \
        "''${PERCENT}% — $profile\n''${energy} Wh at ''${watts}W\n~''${hours}h remaining")

      local sum count avg
      sum=$(calc "$(cat "$BAT/power_now") / 1000000" 4)
      count=1
      for _ in $(seq 1 9); do
        sleep 0.5
        local sample
        sample=$(calc "$(cat "$BAT/power_now") / 1000000" 4)
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

    # Determine target level: user's choice, bumped up for low battery
    target=$USER_LEVEL
    if [ "$STATUS" = "Discharging" ]; then
      [ "$PERCENT" -le 75 ] && [ "$target" -lt 8 ]  && target=8
      [ "$PERCENT" -le 25 ] && [ "$target" -lt 9 ]  && target=9
      [ "$PERCENT" -le 10 ] && [ "$target" -lt 10 ] && target=10
    fi

    # Only act when current level differs from target
    if [ "$CURRENT_LEVEL" != "$target" ]; then
      ${power-mode}/bin/power-mode --auto "$target" > /dev/null 2>&1

      if [ "$STATUS" = "Discharging" ] && [ "$target" -ge 10 ] && [ "$target" -gt "$USER_LEVEL" ]; then
        notify_with_estimate critical "Battery Critical" "emergency mode"
      elif [ "$STATUS" = "Discharging" ] && [ "$target" -ge 9 ] && [ "$target" -gt "$USER_LEVEL" ]; then
        notify_with_estimate normal "Battery Low" "level 9"
      elif [ "$STATUS" = "Discharging" ] && [ "$target" -ge 8 ] && [ "$target" -gt "$USER_LEVEL" ]; then
        ${pkgs.libnotify}/bin/notify-send -u low -t 5000 "Battery ≤75%" "Switched to level 8"
      elif [ "$STATUS" = "Charging" ] && [ "$target" -le "$USER_LEVEL" ]; then
        ${pkgs.libnotify}/bin/notify-send -u low -t 5000 "Charging" "Restored to level $target"
      fi
    fi
  '';

in
{
  powerManagement.powertop.enable = true;

  # Allow power-mode to run as root without password for wheel users
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        { command = "${power-mode}/bin/power-mode"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

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

  systemd.user.timers.battery-watchdog = {
    description = "Poll battery level every 1s";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1s";
      OnUnitActiveSec = "1s";
    };
  };
}
