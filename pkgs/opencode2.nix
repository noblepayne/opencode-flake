{
  stdenv,
  lib,
  fetchzip,
  patchelf,
  baseline ? false,
}: let
  # npm dist-tag "latest" on @opencode scope — v2 stable line
  version = "2.0.29";
  # Per-platform npm packages that contain the actual binary.
  # Default stripRoot=true strips the top-level "package/" directory added by
  # npm during packaging, leaving just bin/opencode — standard nixpkgs convention.
  baseName =
    if baseline
    then "cli-linux-x64-baseline"
    else "cli-linux-x64";
  src = fetchzip {
    url = "https://registry.npmjs.org/@opencode/${baseName}/-/${baseName}-${version}.tgz";
    hash =
      if baseline
      then "sha256-1W8ZbKTzSlGwNXZ0yU9cOCjemDvvzpN4gJA4Iyfr09o="
      else "sha256-6+Q2KJrmv1Et/5GE908ZQK/rZ8jw6ZLd8cPeaBd4VoY=";
  };
  needsPatchelf = stdenv.hostPlatform.isLinux;
in
  stdenv.mkDerivation {
    pname =
      if baseline
      then "opencode2-baseline"
      else "opencode2";
    inherit version;

    # The `let`-bound `src` above is already in scope; re-assigning it here
    # read like a platform dispatch that does not exist.
    inherit src;

    nativeBuildInputs = lib.optionals needsPatchelf [patchelf];

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 bin/opencode $out/bin/opencode2
      ${lib.optionalString needsPatchelf ''
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/opencode2
      ''}
      runHook postInstall
    '';

    meta = with lib; {
      description =
        "AI coding agent built for the terminal (opencode v2 stable)"
        + lib.optionalString baseline " (baseline build — NOT an AVX-free fallback)";
      homepage = "https://github.com/anomalyco/opencode";
      license = licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "opencode2";
    };
  }
