# opencode-flake

A Nix Flake that wraps OpenCode binaries with automatic update capabilities.

## Overview

This flake provides a convenient way to install and maintain up-to-date OpenCode binaries through Nix. It automatically tracks upstream releases and provides both standard and AVX-optimized versions.

## Features

- **Automatic Updates**: GitHub Actions workflows automatically check for and update to new OpenCode releases using the `update.sh` script.
- **Build Validation**: All updates are verified to build correctly *before* being committed or pushed.
- **Health Checks**: OpenCode binaries are validated with a `--version` check to ensure functional integrity.
- **Dual Variants**: Provides both standard (`opencode`) and AVX-optimized (`opencode-avx`) binaries.
- **Flake Integration**: Compatible with NixOS, Home Manager, and standalone Nix usage.

## GitHub Actions Workflows

The repository includes automated workflows that prioritize running the update script first to check for new releases:

1. **Auto Update** (`.github/workflows/auto-update.yml`)
   - Runs twice daily (00:00 and 12:00 UTC).
   - Runs `update.sh` first to fetch and commit new releases from upstream.
   - If updates are found, it validates the builds (`nix build .#opencode` and `.#opencode-avx`) and runs a `--version` check.
   - Pushes to `main` only if validation succeeds.

2. **Update Flake Packages (Weekly PR)** (`.github/workflows/flake-update.yml`)
   - Runs weekly on Sundays at 02:00 UTC.
   - Runs `update.sh` first on a temporary branch to fetch and commit new releases.
   - If updates are found, it validates the builds and binary version strings.
   - Creates a pull request with the updates only after successful validation.

3. **Build and Test** (`.github/workflows/build-test.yml`)
   - Runs daily at 06:00 UTC and on push/PR to main branch.
   - Validates that both opencode packages build successfully.
   - Runs version checks to ensure the binaries are functional.

## Usage

### As a Nix Package

```bash
nix run github:noblepayne/opencode-flake
```

### In a Flake

```nix
{
  inputs.opencode-flake.url = "github:noblepayne/opencode-flake";
  
  outputs = { self, nixpkgs, opencode-flake }: {
    devShells.default = pkgs.mkShell {
      packages = [ opencode-flake.packages.${system}.default ];
    };
  };
}
```

## Maintenance

The flake is designed to be low-maintenance:
- Upstream OpenCode versions are tracked automatically.
- Build validation ensures updates don't break functionality.
- Changes only push after passing build tests.
- All scheduled updates are verified to work correctly.

## Update Script

The `update.sh` script uses `nix-update` to check for new versions of:
- `opencode` - the standard binary.
- `opencode-avx` - the AVX-optimized binary.

When new versions are found, it updates the flake.lock file and commits the changes.
