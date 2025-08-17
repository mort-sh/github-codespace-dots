# github-codespace-dots

Development environment setup for GitHub Codespaces.

## Quick Start

Run the setup script to install and configure all development tools:

```bash
./setup.sh
```

## Installed Tools

The setup script installs and configures the following tools:

- **uv** - Fast Python package manager
- **bun** - JavaScript runtime and package manager (alternative to npm)  
- **Docker** - Container platform (verified and configured)
- **Node.js** - JavaScript runtime (LTS version)
- **npm** - Node package manager
- **npx** - Node package executor

## Features

- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Error handling**: Graceful failure recovery with fallback methods
- ✅ **Auto-configuration**: Updates shell PATH automatically
- ✅ **Verification**: Validates all installations
- ✅ **Colored output**: Clear status indicators

## Usage

After running the setup script, you may need to restart your terminal or run:

```bash
source ~/.bashrc
```

All tools will then be available in your PATH and ready to use.