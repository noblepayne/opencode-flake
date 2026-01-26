# opencode-baseline

Pre-built OpenCode binary without AVX instructions for older x86_64 CPUs.

## Why This Exists

The default OpenCode binary requires AVX CPU extensions. This flake provides the baseline x86_64 binary that works on older processors like Intel Jasper Lake (Pentium/Celeron N6005).

## Usage

### Direct Installation
```bash
nix profile install github:noblepayne/opencode-flake
```

### In NixOS Configuration

Add to your flake inputs:
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    opencode-baseline.url = "github:noblepayne/opencode-flake";
  };

  outputs = { nixpkgs, opencode-baseline, ... }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      modules = [
        { nixpkgs.overlays = [ opencode-baseline.overlays.default ]; }
        ./configuration.nix
      ];
    };
  };
}
```

Then add `opencode` to your system packages or home-manager packages.

### One-Off Run
```bash
nix run github:noblepayne/opencode-flake
```

## What Gets Patched

The binary is fetched from upstream and patched with `patchelf` to use the Nix store interpreter. No other modifications are made.

## Supported Systems

- x86_64-linux only

## License

MIT (matches upstream OpenCode license)

## Upstream

https://github.com/anomalyco/opencode
