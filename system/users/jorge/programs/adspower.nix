{ pkgs, ... }:
let
  version = "8.9.23";

  # Raw contents of the upstream .deb (Electron app under /opt/AdsPower Global).
  unpacked = pkgs.stdenvNoCC.mkDerivation {
    pname = "adspower-global-unpacked";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://version.adspower.net/software/linux-x64-global/${version}/AdsPower-Global-${version}-x64.deb";
      hash = "sha256-NNSUtZdOdaDu7FsumBNVEfHWy8zvCXjtkxfV2KBX2rk=";
    };
    nativeBuildInputs = [ pkgs.dpkg ];
    unpackPhase = "dpkg-deb -x $src .";
    installPhase = ''
      mkdir -p $out
      mkdir -p $out/opt
      cp -r "opt/AdsPower Global" $out/opt/adspower
      cp -r usr/share $out/
    '';
    dontPatchELF = true;
    dontStrip = true;
  };

  # FHS env instead of autoPatchelf: AdsPower downloads its own Chromium
  # ("SunBrowser") kernels into ~/.config at runtime, and those need a
  # normal /usr/lib to run too.
  adspower = pkgs.buildFHSEnv {
    pname = "adspower-global";
    inherit version;
    targetPkgs =
      p: with p; [
        alsa-lib
        at-spi2-atk
        at-spi2-core
        cairo
        cups
        dbus
        expat
        glib
        gtk3
        libdrm
        libgbm
        libglvnd
        libnotify
        libsecret
        libuuid
        libxkbcommon
        mesa
        nspr
        nss
        pango
        systemd
        vulkan-loader
        xdg-utils
        libappindicator-gtk3
        libx11
        libxcb
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
        libxrender
        libxscrnsaver
        libxshmfence
        libxtst
        libxkbfile
      ];
    runScript = "${unpacked}/opt/adspower/adspower_global --no-sandbox";
    extraInstallCommands = ''
      mkdir -p $out/share
      cp -r ${unpacked}/share/icons $out/share/
      mkdir -p $out/share/applications
      substitute ${unpacked}/share/applications/adspower_global.desktop \
        $out/share/applications/adspower_global.desktop \
        --replace-fail '"/opt/AdsPower Global/adspower_global"' "$out/bin/adspower-global"
    '';
  };
in
{
  environment.systemPackages = [ adspower ];
}
