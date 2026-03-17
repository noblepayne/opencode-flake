# GitHub Actions Workflows

This directory contains automated workflows for the opencode-flake repository.

## Workflows

### 1. Auto Commit (`auto-commit.yml`)
- **Purpose**: Maintains repository activity by committing timestamp updates twice daily
- **Schedule**: Runs at 00:00 and 12:00 UTC (every 12 hours)
- **Trigger**: Also manually triggerable via workflow_dispatch
- **Permissions**: `contents: write` (to commit and push changes)
- **Process**:
  1. Checks out repository with full history
  2. Configures git with github-actions bot credentials
  3. Updates a timestamp file with current UTC time
  4. Commits changes if any exist
  5. Pushes to the same branch

### 2. Update Flake Packages (`flake-update.yml`)
- **Purpose**: Automatically updates Nix flake locks using the update.sh script, but only after verifying build and OpenCode server health
- **Schedule**: Runs weekly on Sundays at 02:00 UTC
- **Trigger**: Also manually triggerable via workflow_dispatch
- **Permissions**: 
  - `contents: write` (to commit and push flake updates)
  - `pull-requests: write` (to create PRs)
- **Process**:
  1. Checks out repository with full history
  2. Installs Nix using DeterminateSystems installer
  3. Builds both opencode and opencode-avx packages
  4. Starts OpenCode server and performs health check against `/global/health` endpoint
  5. If build and health check pass, runs the update.sh script (which commits flake updates)
  6. Pushes the committed changes
  7. On schedule or manual trigger, creates a pull request with the updates

### 3. Build and Test (`build-test.yml`)
- **Purpose**: Validates that the flake builds correctly and OpenCode server starts
- **Schedule**: Runs daily at 06:00 UTC
- **Trigger**: Also runs on push and pull_request to main branch
- **Permissions**: `contents: read` (only needs to read repository)
- **Process**:
  1. Checks out repository
  2. Installs Nix using DeterminateSystems installer
  3. Builds both opencode and opencode-avx packages
  4. Starts OpenCode server on port 4096
  5. Performs health check against `/global/health` endpoint
  6. Stops the server after check

## Required Repository Settings

For these workflows to function properly, ensure the following in your repository settings:

### Actions Settings
- Under "Actions" → "General":
  - Allow GitHub Actions to create and approve pull requests
  - Read and write permissions (for workflows that need to commit)

### Secrets
No additional secrets are required beyond the automatically provided `GITHUB_TOKEN`, which is sufficient for:
- Checking out the repository
- Committing and pushing (auto-commit and flake update workflows)
- Creating pull requests (flake update workflow)

Note: The OpenCode health check in the build-test and flake update workflows does not require any API keys as it only checks if the local server is responsive.