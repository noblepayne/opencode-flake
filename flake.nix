{
  description = "OpenCode binaries";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    pkgsBySystem = nixpkgs.lib.getAttrs supportedSystems nixpkgs.legacyPackages;
    forAllPkgs = fn: nixpkgs.lib.mapAttrs (system: pkgs: (fn system pkgs)) pkgsBySystem;

    avxSystems = ["x86_64-linux" "x86_64-darwin"];
    # opencode2 (npm beta) only publishes linux-x64 binaries currently
    opencode2Systems = ["x86_64-linux"];
  in {
    formatter = forAllPkgs (system: pkgs: pkgs.alejandra);

    packages = forAllPkgs (system: pkgs:
      {
        default = pkgs.callPackage ./pkgs/opencode.nix {};
        opencode = pkgs.callPackage ./pkgs/opencode.nix {};
      }
      // nixpkgs.lib.optionalAttrs (builtins.elem system avxSystems) {
        opencode-avx = pkgs.callPackage ./pkgs/opencode-avx.nix {};
      }
      // nixpkgs.lib.optionalAttrs (builtins.elem system opencode2Systems) {
        opencode2 = pkgs.callPackage ./pkgs/opencode2.nix {baseline = true;};
        opencode2-avx = pkgs.callPackage ./pkgs/opencode2.nix {baseline = false;};
      });

    devShells = forAllPkgs (system: pkgs: {
      default = pkgs.mkShell {
        packages = [pkgs.nix-update];
      };
    });

    overlays.default = final: prev: {
      opencode = final.callPackage ./pkgs/opencode.nix {};
      opencode-avx = final.callPackage ./pkgs/opencode-avx.nix {};
      opencode2 = final.callPackage ./pkgs/opencode2.nix {baseline = true;};
      opencode2-avx = final.callPackage ./pkgs/opencode2.nix {baseline = false;};
    };
  };
}
