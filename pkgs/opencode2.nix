{
  stdenv,
  lib,
  fetchzip,
  patchelf,
  baseline ? false,
}: let
  # npm dist-tag "next" — opencode2 beta line (will become 2.0)
  version = "0.0.0-next-17251";
  # Per-platform npm packages that contain the actual binary.
  # NOTE: at this version the AVX and baseline tarballs contain IDENTICAL ELF
  # binaries (BuildID c30f169b...) — the AVX/baseline split is a runtime
  # concern, not a build difference. Both SHAs computed from the exact
  # tarballs published to npm.
  baseName =
    if baseline
    then "cli-linux-x64-baseline"
    else "cli-linux-x64";
  src = fetchzip {
    url = "https://registry.npmjs.org/@opencode-ai/${baseName}/-/${baseName}-${version}.tgz";
    hash =
      if baseline
      then "sha256-XfqtOydJo6tY60Z+iXBAZED1iI+Buh6ECWWo8ofYC3M="
      else "sha256-cgJXWN2JrVkOuFlIaTsp4oNkYVVKH5ytHRkQGvj8l/U=";
    stripRoot = false;
  };
  needsPatchelf = stdenv.isLinux;
in
  stdenv.mkDerivation {
    pname =
      if baseline
      then "opencode2-baseline"
      else "opencode2";
    inherit version;

    src = src;

    nativeBuildInputs = lib.optionals needsPatchelf [patchelf];

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 package/bin/opencode2 $out/bin/opencode2
      ${lib.optionalString needsPatchelf ''
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/opencode2
      ''}
      runHook postInstall
    '';

    meta = with lib; {
      description = "AI coding agent built for the terminal (opencode2 beta)";
      homepage = "https://github.com/anomalyco/opencode";
      license = licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "opencode2";
    };
  }
