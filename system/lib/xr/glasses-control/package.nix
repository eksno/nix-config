{
  stdenvNoCC,
  python3,
  gtk4,
  libadwaita,
  gobject-introspection,
  wrapGAppsHook4,
  systemd,
  procps,
}:

# "Glasses" — GTK4 control panel for the XR session (start/stop VR mode,
# recenter, head-pointer toggle). Deliberately minimal: everything else
# is wayvr config. Visible inside the headset because wayvr captures the
# desktop.
#
# The session lifecycle still shells out to the .scratch test script via
# $GLASSES_VR_SCRIPT; that goes away once the sequence graduates into the
# breezy-hyprland launcher with a polkit-backed privileged path.

stdenvNoCC.mkDerivation {
  pname = "glasses-control";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [
    wrapGAppsHook4
    gobject-introspection
  ];

  buildInputs = [
    gtk4
    libadwaita
    (python3.withPackages (ps: [ ps.pygobject3 ]))
  ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 glasses_control.py $out/share/glasses-control/glasses_control.py

    install -Dm644 /dev/stdin $out/share/applications/no.starti.Glasses.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Glasses
    Comment=Control the XR session on the Rayneo glasses
    Exec=$out/bin/glasses
    Icon=video-display-symbolic
    Categories=Utility;
    EOF

    runHook postInstall
  '';

  # gappsWrapperArgs (GI_TYPELIB_PATH, GSETTINGS_SCHEMAS_PATH, ...) is only
  # populated by wrapGAppsHook4's preFixup hook, so the wrapper has to be
  # built after fixup — not in installPhase.
  postFixup = ''
    makeWrapper ${python3.withPackages (ps: [ ps.pygobject3 ])}/bin/python3 $out/bin/glasses \
      --add-flags $out/share/glasses-control/glasses_control.py \
      --prefix PATH : ${systemd}/bin:${procps}/bin \
      "''${gappsWrapperArgs[@]}"
  '';
}
