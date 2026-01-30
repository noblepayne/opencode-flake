{
  description = "OpenCode baseline binary for x86_64-linux (non-AVX)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    pname = "opencode";
    version = "1.1.42";

    opencode = pkgs.stdenv.mkDerivation rec {
      inherit pname version;
      src = pkgs.fetchzip {
        url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64-baseline.tar.gz";
        hash = "sha256-aWVPx7DAWohnyAjJEJ2qSiZ2IA2dCEIz/8UxbtIbrSM=";
        stripRoot = false;
      };

      nativeBuildInputs = [pkgs.patchelf];

      dontConfigure = true;
      dontBuild = true;
      dontStrip = true;
      dontPatchELF = true;

      installPhase = ''
        runHook preInstall
        install -Dm755 opencode $out/bin/opencode
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/opencode
        runHook postInstall
      '';

      meta = with pkgs.lib; {
        description = "AI coding agent built for the terminal";
        homepage = "https://github.com/anomalyco/opencode";
        license = licenses.mit;
        platforms = ["x86_64-linux"];
        mainProgram = "opencode";
      };
    };

    avx = pkgs.stdenv.mkDerivation rec {
      inherit pname version;
      src = pkgs.fetchzip {
        url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz";
        hash = "sha256-aWVPx7DAWohnyAjJEJ2qSiZ2IA2dCEIz/8UxbtIbrSM=";
        stripRoot = false;
      };

      nativeBuildInputs = [pkgs.patchelf];

      dontConfigure = true;
      dontBuild = true;
      dontStrip = true;
      dontPatchELF = true;

      installPhase = ''
        runHook preInstall
        install -Dm755 opencode $out/bin/opencode
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/opencode
        runHook postInstall
      '';

      meta = with pkgs.lib; {
        description = "AI coding agent built for the terminal";
        homepage = "https://github.com/anomalyco/opencode";
        license = licenses.mit;
        platforms = ["x86_64-linux"];
        mainProgram = "opencode";
      };
    };
  in {
    formatter.${system} = pkgs.alejandra;
    packages.${system} = {
      inherit opencode;
      default = opencode;
      opencode-avx = avx;
    };

    # Also expose as an overlay for use in other flakes
    overlays.default = final: prev: {
      opencode = opencode;
      opencode-avx = avx;
    };
  };
}
