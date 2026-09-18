{
  stdenv,
  lib,
  fetchzip,
  patchelf,
  baseline ? false,
}: let
  # npm dist-tag "latest" on @opencode scope — v2 stable line
  version = "2.0.8";
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
      then "sha256-ppg1RRTdUMJAro3E3A8ddoJVhNwE0Vxp7t8Lt0qIIX4="
      else "sha256-uyBVcw1Nmm/ySuyM6DTwCNZwKH8fCupGup0Q2jaLEK0=";
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
      install -Dm755 bin/opencode $out/bin/opencode2
      ${lib.optionalString needsPatchelf ''
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/opencode2
      ''}
      runHook postInstall
    '';

    meta = with lib; {
      description = "AI coding agent built for the terminal (opencode v2 stable)";
      homepage = "https://github.com/anomalyco/opencode";
      license = licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "opencode2";
    };
  }
