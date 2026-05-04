{
  lib,
  stdenv,
  fetchFromGitHub,
  glib,
}:

stdenv.mkDerivation rec {
  pname = "breezy-gnome";
  version = "2.9.12";

  # `fetchSubmodules` is required because `gnome/src/Sombrero.frag` and
  # `gnome/src/textures/{calibrating,custom_banner}.png` are symlinks into
  # `modules/sombrero/` and `vulkan/`, both pulled in as git submodules.
  # Without them the install copy fails on broken symlinks.
  src = fetchFromGitHub {
    owner = "wheaney";
    repo = "breezy-desktop";
    rev = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-GgGP82SKyWJfv/kvIaWo2471mys20Hr0vWzocbib68A=";
  };

  # `glib-compile-schemas` produces gschemas.compiled, which gnome-shell
  # requires before it'll honor any of the extension's preferences.
  nativeBuildInputs = [ glib ];

  dontConfigure = true;
  dontBuild = true;

  # The schema XML in `gnome/src/schemas/` is a symlink up into
  # `ui/data/com.xronlinux.BreezyDesktop.gschema.xml` (shared between the
  # GNOME extension and the standalone preferences UI). `cp -rL` dereferences
  # symlinks so the resulting extension dir is self-contained. Same trick
  # applies to `textures/` per upstream's own packaging script.
  installPhase = ''
    runHook preInstall

    ext="$out/share/gnome-shell/extensions/breezydesktop@xronlinux.com"
    mkdir -p "$ext"
    cp -rL gnome/src/. "$ext/"
    glib-compile-schemas "$ext/schemas"

    runHook postInstall
  '';

  meta = {
    description = "GNOME Shell extension for world-locked XR virtual displays";
    homepage = "https://github.com/wheaney/breezy-desktop";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
