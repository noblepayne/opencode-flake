# opencode-flake

A Nix Flake that wraps OpenCode binaries with automatic update capabilities.

## Overview

This flake provides a convenient way to install and maintain up-to-date OpenCode binaries through Nix. It automatically tracks upstream releases and provides both standard and AVX-optimized versions.

## Features

- **Automatic Updates**: GitHub Actions workflows automatically check for and update to new OpenCode releases
- **Build Validation**: All updates are verified to build correctly before being committed
- **Health Checks**: OpenCode server functionality is validated as part of the update process
- **Dual Variants**: Provides both standard (`opencode`) and AVX-optimized (`opencode-avx`) binaries
- **Flake Integration**: Compatible with NixOS, Home Manager, and standalone Nix usage

## GitHub Actions Workflows

The repository includes three automated workflows:

1. **Auto Commit** (`.github/workflows/auto-commit.yml`)
   - Runs twice daily (00:00 and 12:00 UTC)
   - Validates that the current flake builds and OpenCode server starts correctly
   - Commits a timestamp update to maintain repository activity
   - Only runs if build and health checks pass

2. **Update Flake Packages** (`.github/workflows/flake-update.yml`)
   - Runs weekly on Sundays at 02:00 UTC
   - Performs build and OpenCode server health validation
   - If successful, runs the update script to check for new OpenCode releases
   - Commits any flake lock updates and pushes to the repository
   - Creates a pull request with the changes (for review before merging)

3. **Build and Test** (`.github/workflows/build-test.yml`)
   - Runs daily at 06:00 UTC and on push/PR to main branch
   - Validates that both opencode packages build successfully
   - Starts OpenCode server and verifies it responds to health checks
   - Provides continuous integration validation

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
      packages = [ opencode-flake.packages.x86_64-linux.default ];
    };
  };
}
```

### NixOS Configuration

```nix
{
  environment.systemPackages = [
    pkgs.opencode-flake.packages.x86_64-linux.opencode
  ];
}
```

## Maintenance

The flake is designed to be low-maintenance:
- Upstream OpenCode versions are tracked automatically
- Build validation ensures updates don't break functionality
- Health checks verify the binaries work as expected
- All changes go through pull request review before being merged to main

## Update Script

The `update.sh` script uses `nix-update` to check for new versions of:
- `opencode` - the standard binary
- `opencode-avx` - the AVX-optimized binary

When new versions are found, it updates the flake.lock file and commits the changes.
