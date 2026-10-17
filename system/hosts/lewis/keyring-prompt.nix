{ lib, pkgs, ... }:
let
  names = [
    "org.gnome.keyring.SystemPrompter"
    "org.gnome.keyring.PrivatePrompter"
  ];
  prompt = pkgs.writeShellScript "lewis-keyring-prompter" ''
    # Chrome triggers this at login, before Hyprland's XWM has adopted the
    # lazily started Xwayland; a window mapped then is never managed and the
    # dialog stays invisible. Wait for the WM check property (max ~15s).
    for _ in $(${pkgs.coreutils}/bin/seq 30); do
      ${pkgs.xprop}/bin/xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep -q "window id" && break
      ${pkgs.coreutils}/bin/sleep 0.5
    done
    ${pkgs.coreutils}/bin/sleep 0.5
    exec ${pkgs.coreutils}/bin/env \
      -u GBM_BACKEND -u LIBVA_DRIVER_NAME -u __GLX_VENDOR_LIBRARY_NAME \
      GDK_BACKEND=x11 GDK_GL=disable LIBGL_ALWAYS_SOFTWARE=1 \
      ${pkgs.gcr_3}/libexec/gcr-prompter "$@"
  '';
  services = pkgs.runCommand "lewis-keyring-prompt-services" { } ''
    mkdir -p "$out"
    ${lib.concatMapStringsSep "\n" (name: ''
        cat > "$out/${name}.service" <<SERVICE
      [D-BUS Service]
      Name=${name}
      Exec=${prompt}
      SERVICE
    '') names}
  '';
in
{
  # User-local activation files take precedence over system service files.
  # Route just the password dialog through the X11/software path that worked
  # on both affected boots, preserving the keyring library and saved secrets.
  system.build.lewisKeyringPrompter = services;
  system.activationScripts.lewisKeyringPrompter = {
    deps = [ "users" ];
    text = ''
      ${pkgs.coreutils}/bin/install -d -o jorge -g users \
        /home/jorge/.local/share/dbus-1/services
      ${lib.concatMapStringsSep "\n" (name: ''
        ${pkgs.coreutils}/bin/install -m 0644 -o jorge -g users \
          ${services}/${name}.service \
          /home/jorge/.local/share/dbus-1/services/${name}.service
      '') names}
    '';
  };
}
