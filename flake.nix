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
    # opencode2 (v2 stable, @opencode npm scope) — linux-x64 for now.
    # NOTE (multi-platform, not enabled): upstream also publishes
    #   @opencode/cli-darwin-arm64, cli-darwin-x64 (+ -baseline),
    #   cli-linux-arm64 (+ -baseline, -musl), cli-linux-x64-musl (+ -baseline),
    #   cli-windows-{x64,arm64} (zip, not fetchzip-tarball).
    # Enabling more systems needs pkgs/opencode2.nix to parameterize baseName
    # per system (currently hardcoded to cli-linux-x64[-baseline]) plus
    # hashes per platform — not just widening this list.
    opencode2Systems = ["x86_64-linux"];
  # v1 packages (opencode / opencode-avx) remain available for anyone still on
    # the 1.x line, but are FROZEN and no longer auto-updated: upstream ships v2
    # tags on the same GitHub repo, which made nix-update chase v2 versions for
    # the v1 package and fail on 404s, taking the v2 updater down with it.
    # See update.sh.
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
