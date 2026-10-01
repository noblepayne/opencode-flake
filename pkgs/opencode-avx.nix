{
  stdenv,
  lib,
  fetchzip,
  patchelf,
}: let
  # FROZEN legacy v1. Not auto-updated — see ../update.sh for why. Kept building
  # so existing consumers don't break; the maintained line is opencode2.
  version = "1.18.33";

  # Only x86_64-linux is real. This file previously carried
  # `hash = "sha256-AAAA...="` placeholders for the other platforms, which are
  # syntactically valid SRI (they decode to 32 zero bytes) so `nix flake check
  # --all-systems` passed clean and the packages advertised platforms they could
  # not actually build. They failed only at build time with a hash mismatch —
  # a confusing error for what is really "not supported here". Absent entries now
  # throw the message below instead.
  srcs = {
    "x86_64-linux" = fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz";
      hash = "sha256-PPIp7te+XkB4qozpleLQxdX0TFQLBHHYmK/HrqT3Fw4=";
      stripRoot = false;
    };
  };
  system = stdenv.hostPlatform.system;
  needsPatchelf = stdenv.hostPlatform.isLinux;
in
  stdenv.mkDerivation {
    pname = "opencode-avx";
    inherit version;

    src =
      srcs.${
        system
      } or (throw ''
        opencode-avx (frozen v1) is only built for x86_64-linux; ${system} is not supported.
        Use opencode2-avx from this flake instead — it is the maintained line.
      '');

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
      description = "AI coding agent built for the terminal (AVX) — frozen v1, unmaintained";
      homepage = "https://github.com/anomalyco/opencode";
      license = licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "opencode";
    };
  }
