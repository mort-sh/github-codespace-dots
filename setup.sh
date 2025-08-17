#!/bin/bash

# GitHub Codespace Development Environment Setup Script
# This script installs and configures development tools for use in GitHub Codespaces

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if we're running in a supported environment
check_environment() {
    log_info "Checking environment..."
    
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "This script is designed for Linux environments (GitHub Codespaces)"
        exit 1
    fi
    
    if ! command_exists "curl"; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    log_success "Environment check passed"
}

# Install Python's uv package manager
install_uv() {
    log_info "Installing Python's uv package manager..."
    
    if command_exists "uv"; then
        log_warning "uv is already installed, skipping..."
        uv --version
        return 0
    fi
    
    # Try multiple installation methods
    local install_success=false
    
    # Method 1: Official installation script
    log_info "Trying official installation script..."
    if curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null; then
        install_success=true
    else
        log_warning "Official installation script failed, trying alternative method..."
        
        # Method 2: Using pip if available
        if command_exists "pip3" || command_exists "pip"; then
            log_info "Trying installation via pip..."
            local pip_cmd
            if command_exists "pip3"; then
                pip_cmd="pip3"
            else
                pip_cmd="pip"
            fi
            
            if $pip_cmd install --user uv 2>/dev/null; then
                install_success=true
                # Add pip user bin to PATH
                export PATH="$HOME/.local/bin:$PATH"
            fi
        fi
        
        # Method 3: Direct GitHub release download as fallback
        if [ "$install_success" = false ]; then
            log_info "Trying direct download from GitHub releases..."
            local arch
            arch=$(uname -m)
            local os="unknown-linux-gnu"
            
            case "$arch" in
                x86_64) arch="x86_64" ;;
                aarch64|arm64) arch="aarch64" ;;
                *) log_warning "Unsupported architecture: $arch" ;;
            esac
            
            local download_url="https://github.com/astral-sh/uv/releases/latest/download/uv-${arch}-${os}.tar.gz"
            local temp_dir=$(mktemp -d)
            
            if curl -L "$download_url" | tar -xz -C "$temp_dir" 2>/dev/null; then
                mkdir -p "$HOME/.local/bin"
                if cp "$temp_dir/uv-${arch}-${os}/uv" "$HOME/.local/bin/uv" 2>/dev/null; then
                    chmod +x "$HOME/.local/bin/uv"
                    export PATH="$HOME/.local/bin:$PATH"
                    install_success=true
                fi
            fi
            rm -rf "$temp_dir"
        fi
    fi
    
    # Add uv to PATH for current session
    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
    
    # Verify installation
    if command_exists "uv" && [ "$install_success" = true ]; then
        log_success "uv installed successfully"
        uv --version
    else
        log_warning "Failed to install uv, but continuing with other tools..."
        return 0  # Don't fail the entire script
    fi
}

# Install bun (JavaScript runtime and package manager)
install_bun() {
    log_info "Installing bun (JavaScript runtime and package manager)..."
    
    if command_exists "bun"; then
        log_warning "bun is already installed, skipping..."
        bun --version
        return 0
    fi
    
    # Try multiple installation methods
    local install_success=false
    
    # Method 1: Official installation script
    log_info "Trying official bun installation script..."
    if curl -fsSL https://bun.sh/install | bash 2>/dev/null; then
        install_success=true
    else
        log_warning "Official installation script failed, trying alternative method..."
        
        # Method 2: Direct GitHub release download
        log_info "Trying direct download from GitHub releases..."
        local arch
        arch=$(uname -m)
        local os="linux"
        
        case "$arch" in
            x86_64) arch="x64" ;;
            aarch64|arm64) arch="aarch64" ;;
            *) log_warning "Unsupported architecture: $arch" ;;
        esac
        
        local download_url="https://github.com/oven-sh/bun/releases/latest/download/bun-${os}-${arch}.zip"
        local temp_dir=$(mktemp -d)
        
        if command_exists "unzip" && curl -L "$download_url" -o "$temp_dir/bun.zip" 2>/dev/null; then
            if unzip "$temp_dir/bun.zip" -d "$temp_dir" 2>/dev/null; then
                mkdir -p "$HOME/.bun/bin"
                if cp "$temp_dir/bun-${os}-${arch}/bun" "$HOME/.bun/bin/bun" 2>/dev/null; then
                    chmod +x "$HOME/.bun/bin/bun"
                    install_success=true
                fi
            fi
        fi
        rm -rf "$temp_dir"
        
        # Method 3: Try npm installation as fallback
        if [ "$install_success" = false ] && command_exists "npm"; then
            log_info "Trying installation via npm..."
            if npm install -g bun 2>/dev/null; then
                install_success=true
            fi
        fi
    fi
    
    # Add bun to PATH for current session
    export PATH="$HOME/.bun/bin:$PATH"
    
    # Verify installation
    if command_exists "bun" && [ "$install_success" = true ]; then
        log_success "bun installed successfully"
        bun --version
    else
        log_warning "Failed to install bun, but continuing with other tools..."
        return 0  # Don't fail the entire script
    fi
}

# Setup Docker
setup_docker() {
    log_info "Setting up Docker..."
    
    if command_exists "docker"; then
        log_warning "Docker is already available"
        docker --version
        
        # Check if docker daemon is running
        if docker info >/dev/null 2>&1; then
            log_success "Docker daemon is running"
        else
            log_warning "Docker daemon is not running, but this is normal in Codespaces"
            log_info "Docker commands will work when containers are started"
        fi
        return 0
    fi
    
    # In GitHub Codespaces, Docker is typically pre-installed
    # If not available, we'll install it
    log_info "Installing Docker..."
    
    # Update package index
    sudo apt-get update
    
    # Install required packages
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index
    sudo apt-get update
    
    # Install Docker Engine
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group (if not in Codespaces where this might be handled differently)
    if ! groups | grep -q docker; then
        sudo usermod -aG docker "$USER"
        log_warning "Added user to docker group. You may need to restart your session."
    fi
    
    if command_exists "docker"; then
        log_success "Docker installed successfully"
        docker --version
    else
        log_error "Failed to install Docker"
        return 1
    fi
}

# Install/Update Node.js, npm, and npx
setup_nodejs() {
    log_info "Setting up Node.js, npm, and npx..."
    
    # Check if Node.js is already installed
    if command_exists "node" && command_exists "npm"; then
        log_info "Node.js and npm are already installed"
        node --version
        npm --version
        
        # Check if it's a recent LTS version (18.x or higher)
        NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -ge 18 ]; then
            log_success "Node.js version is recent enough"
            return 0
        else
            log_warning "Node.js version is older than LTS, updating..."
        fi
    fi
    
    # Install Node.js using NodeSource repository (for latest LTS)
    log_info "Installing Node.js LTS..."
    
    # Download and run the NodeSource setup script for Node.js LTS
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    
    # Install Node.js
    sudo apt-get install -y nodejs
    
    # Verify installation
    if command_exists "node" && command_exists "npm" && command_exists "npx"; then
        log_success "Node.js ecosystem installed successfully"
        node --version
        npm --version
        npx --version
    else
        log_error "Failed to install Node.js ecosystem"
        return 1
    fi
}

# Update shell configuration to include new PATHs
update_shell_config() {
    log_info "Updating shell configuration..."
    
    # Determine the shell config file
    SHELL_CONFIG=""
    if [ -n "${BASH_VERSION:-}" ]; then
        SHELL_CONFIG="$HOME/.bashrc"
    elif [ -n "${ZSH_VERSION:-}" ]; then
        SHELL_CONFIG="$HOME/.zshrc"
    else
        SHELL_CONFIG="$HOME/.profile"
    fi
    
    # Add paths to shell config if they don't exist
    if ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' "$SHELL_CONFIG" 2>/dev/null; then
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$SHELL_CONFIG"
        log_info "Added uv (cargo) to PATH in $SHELL_CONFIG"
    fi
    
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_CONFIG" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_CONFIG"
        log_info "Added local bin to PATH in $SHELL_CONFIG"
    fi
    
    if ! grep -q 'export PATH="$HOME/.bun/bin:$PATH"' "$SHELL_CONFIG" 2>/dev/null; then
        echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$SHELL_CONFIG"
        log_info "Added bun to PATH in $SHELL_CONFIG"
    fi
    
    log_success "Shell configuration updated"
}

# Print summary of installed tools
print_summary() {
    log_info "Installation Summary:"
    echo "======================================"
    
    if command_exists "uv"; then
        echo -e "${GREEN}✓${NC} uv: $(uv --version)"
    else
        echo -e "${RED}✗${NC} uv: Not installed"
    fi
    
    if command_exists "bun"; then
        echo -e "${GREEN}✓${NC} bun: $(bun --version)"
    else
        echo -e "${RED}✗${NC} bun: Not installed"
    fi
    
    if command_exists "docker"; then
        echo -e "${GREEN}✓${NC} docker: $(docker --version)"
    else
        echo -e "${RED}✗${NC} docker: Not installed"
    fi
    
    if command_exists "node"; then
        echo -e "${GREEN}✓${NC} node: $(node --version)"
    else
        echo -e "${RED}✗${NC} node: Not installed"
    fi
    
    if command_exists "npm"; then
        echo -e "${GREEN}✓${NC} npm: $(npm --version)"
    else
        echo -e "${RED}✗${NC} npm: Not installed"
    fi
    
    if command_exists "npx"; then
        echo -e "${GREEN}✓${NC} npx: $(npx --version)"
    else
        echo -e "${RED}✗${NC} npx: Not installed"
    fi
    
    echo "======================================"
    log_success "Setup complete! You may need to restart your terminal or run 'source $HOME/.bashrc' to use all tools."
}

# Main execution
main() {
    log_info "Starting GitHub Codespace development environment setup..."
    
    check_environment
    
    # Install tools
    install_uv
    install_bun
    setup_docker
    setup_nodejs
    
    # Update configuration
    update_shell_config
    
    # Show summary
    print_summary
    
    log_success "Setup script completed successfully!"
}

# Run main function
main "$@"