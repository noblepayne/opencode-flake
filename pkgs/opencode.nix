{
  stdenv,
  lib,
  fetchzip,
  patchelf,
}: let
  # FROZEN legacy v1. Not auto-updated — see ../update.sh for why. Keep this pin
  # working (don't chase upstream); the maintained line is opencode2.
  version = "1.18.33";
  # NOTE: at 1.18.33 upstream ships byte-identical baseline and AVX tarballs
  # (both prefetch to sha256-J840fbg...), so the avx/baseline split that gave
  # this file and opencode-avx.nix distinct hashes is now vestigial.
  srcs = {
    "x86_64-linux" = fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64-baseline.tar.gz";
      hash = "sha256-PPIp7te+XkB4qozpleLQxdX0TFQLBHHYmK/HrqT3Fw4=";
      stripRoot = false;
    };
    "aarch64-linux" = fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-arm64.tar.gz";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      stripRoot = false;
    };
    "aarch64-darwin" = fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      stripRoot = false;
    };
    "x86_64-darwin" = fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-x64-baseline.zip";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      stripRoot = false;
    };
  };
  system = stdenv.hostPlatform.system;
  needsPatchelf = stdenv.isLinux;
in
  stdenv.mkDerivation {
    pname = "opencode";
    inherit version;

    src = srcs.${system} or (throw "unsupported system: ${system}");

    nativeBuildInputs = lib.optionals needsPatchelf [patchelf];

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 opencode $out/bin/opencode
      ${lib.optionalString needsPatchelf ''
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/opencode
      ''}
      runHook postInstall
    '';

    meta = with lib; {
      description = "AI coding agent built for the terminal";
      homepage = "https://github.com/anomalyco/opencode";
      license = licenses.mit;
      platforms = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
      mainProgram = "opencode";
    };
  }
