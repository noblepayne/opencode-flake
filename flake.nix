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

    # v1 packages (opencode / opencode-avx) remain available for anyone still
    # on the 1.x line, but are FROZEN at 1.18.33 and no longer auto-updated:
    # upstream ships v2 tags on the same GitHub repo, which made nix-update
    # chase v2 versions for the v1 package and fail on 404s, taking the v2
    # updater down with it. See update.sh.
    #
    # v1 is x86_64-linux only. It used to declare aarch64/darwin entries with
    # `hash = "sha256-AAAA...="` placeholders — syntactically valid SRI, so
    # `nix flake check --all-systems` passed while the packages claimed
    # platforms they could not build (they failed at build time with a hash
    # mismatch). Gating on the system list makes the attributes simply not
    # exist where they cannot be built.
    #
    # Git history preserves the old pins if you ever need them back.
    v1Systems = ["x86_64-linux"];

    # opencode2 (v2 stable, @opencode npm scope) — x86_64-linux only.
    #
    # Verified against @opencode/cli 2.0.21 optionalDependencies. Upstream
    # publishes these platform packages:
    #   linux-x64   : cli-linux-x64,  cli-linux-x64-baseline,
    #                 cli-linux-x64-musl, cli-linux-x64-baseline-musl
    #   linux-arm64 : cli-linux-arm64, cli-linux-arm64-musl      (NO baseline)
    #   darwin-x64  : cli-darwin-x64,  cli-darwin-x64-baseline
    #   darwin-arm64: cli-darwin-arm64                           (NO baseline)
    #   windows     : cli-windows-{x64,arm64} (zip, not fetchzip-tarball)
    #
    # Two things to know before widening this list:
    #   1. There is NO arm64 baseline build, so the opencode2/opencode2-avx
    #      split cannot be reproduced on aarch64 at all.
    #   2. Enabling a system needs pkgs/opencode2.nix to parameterize the npm
    #      package name per system (currently hardcoded to
    #      cli-linux-x64[-baseline]) plus a hash per platform — AND update-v2.sh
    #      to iterate that matrix. Widening this list alone does nothing.
    #
    # Note: "-baseline" is NOT a pre-AVX fallback for v2. The 2.0.21 baseline
    # and non-baseline binaries differ by 3,231 bytes out of 204 MB
    # (JavaScriptCore inline-cache constants) and both carry the same AVX-512
    # instruction profile (779,532 vs 779,938 EVEX-prefixed bytes). Bun
    # dropped genuinely AVX-free baseline builds; nixpkgs' own `bun` package
    # notes the same. The split is kept only to mirror upstream's naming.
    opencode2Systems = ["x86_64-linux"];
  in {
    formatter = forAllPkgs (system: pkgs: pkgs.alejandra);

    packages = forAllPkgs (system: pkgs:
      nixpkgs.lib.optionalAttrs (builtins.elem system v1Systems) {
        opencode = pkgs.callPackage ./pkgs/opencode.nix {};
        opencode-avx = pkgs.callPackage ./pkgs/opencode-avx.nix {};
      }
      // nixpkgs.lib.optionalAttrs (builtins.elem system opencode2Systems) {
        # `default` is the maintained v2 line. It used to point at frozen v1,
        # so `nix run github:noblepayne/opencode-flake` — the quickstart in
        # README.md — handed you the dead 1.x binary with no error.
        default = pkgs.callPackage ./pkgs/opencode2.nix {baseline = true;};
        opencode2 = pkgs.callPackage ./pkgs/opencode2.nix {baseline = true;};
        opencode2-avx = pkgs.callPackage ./pkgs/opencode2.nix {baseline = false;};
      });

    # Toolchain that update-v2.sh actually uses (curl + python3). nix-update is
    # gone: v1 is frozen, so nothing invokes it anymore. Without these the
    # "reproducible toolchain" claim in auto-update.yml was false — curl and
    # python3 were coming from the runner image's ambient PATH.
    devShells = forAllPkgs (system: pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.curl
          pkgs.python3
        ];
      };
    });

    # Mirrors the per-system gating of `packages`. An unguarded overlay entry
    # is a thunk that either throws or resolves to a binary built for the wrong
    # architecture. Prefer referencing packages.<system>.* directly: mixing both
    # produces two distinct derivations of the same binary from two different
    # nixpkgs.
    overlays.default = final: prev:
      nixpkgs.lib.optionalAttrs (builtins.elem final.stdenv.hostPlatform.system v1Systems) {
        opencode = final.callPackage ./pkgs/opencode.nix {};
        opencode-avx = final.callPackage ./pkgs/opencode-avx.nix {};
      }
      // nixpkgs.lib.optionalAttrs (builtins.elem final.stdenv.hostPlatform.system opencode2Systems) {
        opencode2 = final.callPackage ./pkgs/opencode2.nix {baseline = true;};
        opencode2-avx = final.callPackage ./pkgs/opencode2.nix {baseline = false;};
      };
  };
}
