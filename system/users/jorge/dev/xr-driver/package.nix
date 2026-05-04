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
  systemd, # provides libudev (hidapi + viture libglasses link against it)
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
    # `bin/build_custom_banner_config.py` imports yaml during the build.
    (python3.withPackages (ps: [ ps.pyyaml ]))
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
    systemd
    # Vendor blobs (libcarina_vio.so, libopencv_*.so.4.2) are linked against
    # libstdc++ from the Ubuntu toolchain they were built with — provide it
    # so autoPatchelfHook can resolve them.
    gcc-unwrapped.lib
  ];

  # Top-level CMakeLists runs `git submodule update --init --recursive` at
  # configure time. Submodules are already present from fetchSubmodules, and
  # the sandbox has no network — neuter the call.
  #
  # Also drop the optional XREAL One Rust subdriver. It's only used for the
  # XREAL One model, gated by `if(EXISTS .../xreal_one_driver.h)` in the
  # interface_lib CMake — removing the file disables it. Building it would
  # require vendoring Cargo deps for offline cargo, which isn't worth it for
  # a Rayneo-focused build.
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-quiet "git submodule update --init --recursive" "true"
    rm -rf modules/xrealInterfaceLibrary/interface_lib/modules/xreal_one_driver

    # Upstream Rayneo udev rule only matches `SUBSYSTEM=="usb"`, which means
    # systemd-logind never grants the seat-active user access to the device's
    # /dev/hidrawN node — and libhidapi opens hidraw, not raw USB. Append a
    # hidraw match (mirrors what upstream's viture rule already does).
    cat >> udev/70-rayneo-xr.rules <<'EOF'

    SUBSYSTEM=="hidraw", KERNEL=="hidraw[0-9]*", ATTRS{idVendor}=="1bbb", MODE="0660", TAG+="uaccess"
    EOF

    # Upstream uinput rule only sets static_node; perms stay 0600 root:root,
    # so xrDriver fails with "libevdev_uinput_create_from_device: Permission
    # denied" when it tries to register the virtual mouse. Replace with a
    # rule that also grants the seat-active user access via uaccess.
    cat > udev/70-uinput-xr.rules <<'EOF'
    KERNEL=="uinput", MODE="0660", TAG+="uaccess", OPTIONS+="static_node=uinput"
    EOF

    # hid_ids.c references `imu_protocol_xreal_one` even though we removed
    # the XREAL One driver dir above. Provide a stub with non-NULL function
    # pointers that just return error — `plugins.start()` enumerates all
    # registered protocols, so NULL-init'd struct members crash the driver
    # before it ever gets to its main loop.
    cat > modules/xrealInterfaceLibrary/interface_lib/src/imu_protocol_xo_stub.c <<'EOF'
    #include "imu_protocol.h"
    static bool xo_open(struct device_imu_t* d, const struct imu_hid_info* i) { (void)d; (void)i; return false; }
    static void xo_close(struct device_imu_t* d) { (void)d; }
    static bool xo_start_stream(struct device_imu_t* d) { (void)d; return false; }
    static bool xo_stop_stream(struct device_imu_t* d) { (void)d; return false; }
    static bool xo_get_static_id(struct device_imu_t* d, uint32_t* o) { (void)d; (void)o; return false; }
    static bool xo_load_cal(struct device_imu_t* d, uint32_t* l, char** o) { (void)d; (void)l; (void)o; return false; }
    static int  xo_next_sample(struct device_imu_t* d, struct imu_sample* o, int t) { (void)d; (void)o; (void)t; return -1; }
    const imu_protocol imu_protocol_xreal_one = {
        .open = xo_open,
        .close = xo_close,
        .start_stream = xo_start_stream,
        .stop_stream = xo_stop_stream,
        .get_static_id = xo_get_static_id,
        .load_calibration_json = xo_load_cal,
        .next_sample = xo_next_sample,
    };
    EOF
    substituteInPlace modules/xrealInterfaceLibrary/interface_lib/CMakeLists.txt \
      --replace-fail \
        "src/hid_ids.c" \
        "src/hid_ids.c src/imu_protocol_xo_stub.c"
  '';

  # The VITURE libglasses.so blob and the vendored hidapi-hidraw both have
  # DT_NEEDED entries for libudev (LIBUDEV_183). At link time the linker
  # walks shared-lib deps and bails on the unresolved symbols. Tell it to
  # leave shared-lib undefined refs to runtime — they'll resolve via the
  # LD_LIBRARY_PATH wrap on the binary.
  cmakeFlags = [
    "-DCMAKE_EXE_LINKER_FLAGS=-Wl,--unresolved-symbols=ignore-in-shared-libs"
    # Don't bake the build directory into RPATH — autoPatchelfHook sets the
    # install-time RPATH from buildInputs + $out/lib.
    "-DCMAKE_SKIP_BUILD_RPATH=ON"
  ];

  # nixpkgs defaults to `_FORTIFY_SOURCE=3` which trips on a borderline
  # fprintf in upstream's early init (via __fprintf_chk). The upstream CI
  # builds with looser fortify and never sees this — disable it here so
  # we match upstream behavior. Driver crashes between "Using hardware id"
  # and "Starting up XR driver" with FORTIFY enabled.
  hardeningDisable = [
    "fortify"
    "fortify3"
  ];

  # CMakeLists ships no install() rules (upstream installs via shell scripts
  # straight to ~/.local). Lay it out manually under $out:
  #   bin/xrDriver
  #   lib/*.so                     (vendor SDK blobs the driver dlopens)
  #   lib/udev/rules.d/*.rules     (XR device + uinput rules)
  #   lib/systemd/user/xr-driver.service
  installPhase = ''
    runHook preInstall

    # cmake builds inside ./build, so source files are one level up.
    install -Dm755 xrDriver "$out/bin/xrDriver"

    install -d "$out/lib"

    # Libs cmake just built (vendored hidapi from the xrealInterfaceLibrary
    # submodule). xrDriver's DT_NEEDED references libhidapi-hidraw.so.0 —
    # without these in $out/lib it crashes with "cannot open shared object".
    cp -P modules/xrealInterfaceLibrary/interface_lib/modules/hidapi/src/linux/libhidapi-hidraw.so* "$out/lib/"
    cp -P modules/xrealInterfaceLibrary/interface_lib/modules/hidapi/src/libusb/libhidapi-libusb.so* "$out/lib/"

    # Pre-built vendor blobs the driver dlopens at runtime. Includes a
    # viture/ subdir with bundled OpenCV libs the VITURE SDK depends on;
    # mirror the layout so dlopen lookups resolve relative to LD_LIBRARY_PATH.
    cp -rP ../lib/x86_64/* "$out/lib/"

    install -d "$out/lib/udev/rules.d"
    cp ../udev/*.rules "$out/lib/udev/rules.d/"

    install -d "$out/lib/systemd/user"
    sed \
      -e "s|{ld_library_path}|$out/lib:$out/lib/viture|g" \
      -e "s|{bin_dir}|$out/bin|g" \
      ../systemd/xr-driver.service \
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
