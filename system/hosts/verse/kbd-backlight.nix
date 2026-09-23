{ pkgs, ... }:
let
  led = "asus::kbd_backlight";

  # `|| true` matters: resumeCommands are concatenated into one `set -e` script
  # shared with corne-bt-recovery and power-mode, so a failure here would abort
  # the hooks that run after it.
  offHook = pkgs.writeShellScript "kbd-backlight-off" ''
    echo 0 > /sys/class/leds/${led}/brightness 2>/dev/null || true
  '';
in
{
  # Keep the keyboard backlight off. asus-nb-wmi re-lights the LED whenever the
  # device is (re)created and again on wake, so a single write doesn't stick --
  # cover device appearance (udev), boot (oneshot), and resume (hook).
  # Fn+F7 still raises it manually; this only sets the default.

  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="leds", KERNEL=="${led}", ATTR{brightness}="0"
  '';

  # `lines` type -> merges with power-mode's and corne-bt-recovery's hooks.
  powerManagement.resumeCommands = "${offHook}";

  systemd.services.kbd-backlight-off = {
    description = "Turn off the keyboard backlight";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${offHook}";
      RemainAfterExit = true;
    };
  };
}
