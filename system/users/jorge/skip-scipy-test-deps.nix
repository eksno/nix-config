{ ... }:
# Keep scipy out of the build. cache.nixos.org has no scipy for this nixpkgs
# revision, so it compiled locally three times (py3.12/3.13/3.14) and froze
# lewis. Nothing installed uses scipy; every path to it is a test or lint
# dependency of some other package:
#
#   phonetic -> pynput -(setup_requires)-> setuptools-lint -> pylint -> isort -> ... -> scipy
#   isort -(tests)-> pylama -> vulture -(tests)-> pint -> uncertainties -> scipy
#   waypaper -> imageio -(tests)-> astropy -> scipy
#
# Skip those tests and drop pynput's lint-only setup requirement. The changed
# packages are small pure-Python builds. Drop this once Hydra caches scipy again.
# See FIXES.md 2026-10-10.
{
  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (pyfinal: pyprev: {
          pynput = pyprev.pynput.overridePythonAttrs (old: {
            nativeBuildInputs = builtins.filter (
              d: (d.pname or "") != "setuptools-lint"
            ) old.nativeBuildInputs;
            postPatch = old.postPatch + ''
              substituteInPlace setup.py \
                --replace-fail "'setuptools-lint >=0.5'," ""
            '';
          });
          isort = pyprev.isort.overridePythonAttrs { doCheck = false; };
          vulture = pyprev.vulture.overridePythonAttrs { doCheck = false; };
          imageio = pyprev.imageio.overridePythonAttrs { doCheck = false; };
        })
      ];
    })
  ];
}
