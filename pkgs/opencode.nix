{
  stdenv,
  lib,
  fetchzip,
  patchelf,
}: let
  # FROZEN legacy v1. Not auto-updated — see ../update.sh for why. Kept building
  # so existing consumers don't break; the maintained line is opencode2.
  version = "1.18.33";
  #
  # Note on the historical avx/baseline split: this file was "baseline" and
  # opencode-avx.nix was "AVX", back when Bun's baseline build was genuinely
  # AVX-free. At 1.18.33 upstream ships byte-identical tarballs for both names
  # (both prefetch to sha256-J840fbgHd4LcXGsxUohTb+70tfAnR7VkXPVaO3swjsU=), so
  # the distinction no longer exists and both files carry the same hash.
  #
  # Only x86_64-linux is real. The other platforms previously had
  # `hash = "sha256-AAAA...="` placeholders — valid SRI, so `nix flake check
  # --all-systems` passed and the package claimed platforms it could not build.
  # They failed only at build time with a hash mismatch. Absent entries now
  # throw instead.
  srcs = {
    "x86_64-linux" = fetchzip {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64-baseline.tar.gz";
      hash = "sha256-PPIp7te+XkB4qozpleLQxdX0TFQLBHHYmK/HrqT3Fw4=";
      stripRoot = false;
    };
  };
  system = stdenv.hostPlatform.system;
  needsPatchelf = stdenv.hostPlatform.isLinux;
in
  stdenv.mkDerivation {
    pname = "opencode";
    inherit version;

    src =
      srcs.${
        system
      } or (throw ''
        opencode (frozen v1) is only built for x86_64-linux; ${system} is not supported.
        Use opencode2 from this flake instead — it is the maintained line.
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
      description = "AI coding agent built for the terminal — frozen v1, unmaintained";
      homepage = "https://github.com/anomalyco/opencode";
      license = licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "opencode";
    };
  }
