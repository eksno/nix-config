{
  lib,
  stdenv,
  fetchgit,
  cmake,
  pkg-config,
  python3,
  makeWrapper,
  libusb1,
  libevdev,
  openssl,
  json_c,
  curl,
  wayland,
  autoPatchelfHook,
  gcc-unwrapped,
}:

stdenv.mkDerivation rec {
  pname = "xr-linux-driver";
  version = "2.9.4";

  # `fetchgit` (vs `fetchFromGitHub`) is used because XRLinuxDriver pulls
  # `xrealInterfaceLibrary` from gitlab as a submodule, which itself has
  # nested submodules (Fusion, hidapi). Recursive submodule following
  # across hosts is most reliable through fetchgit.
  src = fetchgit {
    url = "https://github.com/wheaney/XRLinuxDriver.git";
    rev = "v${version}";
    fetchSubmodules = true;
    deepClone = false;
    hash = "sha256-fbaNdv6vjRphYYSzbOYqmRK6c24hv1gkTh3xlql0VEU=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    python3
    makeWrapper
    autoPatchelfHook
  ];

  buildInputs = [
    libusb1
    libevdev
    openssl
    json_c
    curl
    wayland
    # Vendor blobs (libcarina_vio.so, libopencv_*.so.4.2) are linked against
    # libstdc++ from the Ubuntu toolchain they were built with — provide it
    # so autoPatchelfHook can resolve them.
    gcc-unwrapped.lib
  ];

  # Top-level CMakeLists runs `git submodule update --init --recursive` at
  # configure time. Submodules are already present from fetchSubmodules, and
  # the sandbox has no network — neuter the call.
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-quiet "git submodule update --init --recursive" "true"
  '';

  # CMakeLists ships no install() rules (upstream installs via shell scripts
  # straight to ~/.local). Lay it out manually under $out:
  #   bin/xrDriver
  #   lib/*.so                     (vendor SDK blobs the driver dlopens)
  #   lib/udev/rules.d/*.rules     (XR device + uinput rules)
  #   lib/systemd/user/xr-driver.service
  installPhase = ''
    runHook preInstall

    install -Dm755 xrDriver "$out/bin/xrDriver"

    # Vendor blobs the driver dlopens at runtime. Includes a viture/ subdir
    # with bundled OpenCV libs the VITURE SDK depends on; mirror the layout
    # so dlopen lookups resolve relative to LD_LIBRARY_PATH.
    install -d "$out/lib"
    cp -rP "$NIX_BUILD_TOP/source/lib/x86_64/"* "$out/lib/"

    install -d "$out/lib/udev/rules.d"
    cp "$NIX_BUILD_TOP/source/udev/"*.rules "$out/lib/udev/rules.d/"

    install -d "$out/lib/systemd/user"
    sed \
      -e "s|{ld_library_path}|$out/lib:$out/lib/viture|g" \
      -e "s|{bin_dir}|$out/bin|g" \
      "$NIX_BUILD_TOP/source/systemd/xr-driver.service" \
      > "$out/lib/systemd/user/xr-driver.service"

    runHook postInstall
  '';

  # xrDriver dlopens the vendor SDKs (libRayNeoXRMiniSDK.so etc.) at runtime —
  # plumb $out/lib (and the viture/ subdir for its bundled OpenCV) onto
  # LD_LIBRARY_PATH so dlopen finds them without needing the systemd unit.
  postFixup = ''
    wrapProgram "$out/bin/xrDriver" \
      --prefix LD_LIBRARY_PATH : "$out/lib:$out/lib/viture"
  '';

  # autoPatchelfHook will trip on the proprietary blobs that link against
  # an older libstdc++ ABI. They work at runtime via LD_LIBRARY_PATH, but
  # patchelf can't find every transitive ref — don't fail on them.
  dontAutoPatchelf = false;
  autoPatchelfIgnoreMissingDeps = [
    "libRayNeoXRMiniSDK.so"
    "libGlassSDK.so"
    "libcarina_vio.so"
    "libglasses.so"
    "libopencv_*.so*"
  ];

  meta = {
    description = "Userspace driver for XR / smart glasses (XREAL, Viture, Rayneo, Rokid)";
    homepage = "https://github.com/wheaney/XRLinuxDriver";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    # Vendor SDKs in lib/x86_64 are proprietary and dlopen'd at runtime;
    # required for Rayneo + Rokid families.
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
  };
}
