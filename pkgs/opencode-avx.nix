{
  stdenv,
  lib,
  fetchzip,
  patchelf,
}: let
  version = "1.18.1";
  srcs = {
    "x86_64-linux" = fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz";
      hash = "sha256-ZVl7zvVaREq+Ch8KhHbz8zD9Knb3ovQuUWLfyuQexaQ=";
      stripRoot = false;
    };
    "x86_64-darwin" = fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-x64.zip";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      stripRoot = false;
    };
  };
  system = stdenv.hostPlatform.system;
  needsPatchelf = stdenv.isLinux;
in
  stdenv.mkDerivation {
    pname = "opencode-avx";
    inherit version;

    src = srcs.${system} or (throw "unsupported system for AVX variant: ${system}");

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
      description = "AI coding agent built for the terminal (AVX)";
      homepage = "https://github.com/anomalyco/opencode";
      license = licenses.mit;
      platforms = ["x86_64-linux" "x86_64-darwin"];
      mainProgram = "opencode";
    };
  }
