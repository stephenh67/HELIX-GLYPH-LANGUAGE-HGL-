#!/usr/bin/env bash

# SPDX-License-Identifier: Apache-2.0
# WSL/Ubuntu Setup Script for HGL Infrastructure
#
# This script installs all necessary tools and dependencies for HGL
# verification, development, and CI/CD workflows.
#
# Usage:
#   chmod +x setup_wsl_for_hgl.sh
#   ./setup_wsl_for_hgl.sh

set -euo pipefail

# Colors
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[32m'
COLOR_YELLOW='\033[33m'
COLOR_RED='\033[31m'
COLOR_CYAN='\033[36m'
COLOR_BLUE='\033[34m'
COLOR_MAGENTA='\033[35m'

log_info() {
    echo -e "${COLOR_CYAN}▶ $*${COLOR_RESET}"
}

log_success() {
    echo -e "${COLOR_GREEN}✓ $*${COLOR_RESET}"
}

log_warning() {
    echo -e "${COLOR_YELLOW}⚠ $*${COLOR_RESET}"
}

log_error() {
    echo -e "${COLOR_RED}✗ $*${COLOR_RESET}" >&2
}

log_header() {
    echo
    echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}$*${COLOR_RESET}"
    echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
}

log_section() {
    echo
    echo -e "${COLOR_MAGENTA}>>> $*${COLOR_RESET}"
}

# Check if running on WSL
check_wsl() {
    if grep -qi microsoft /proc/version; then
        log_success "Running on WSL"
        return 0
    elif [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
        log_success "Running on WSL"
        return 0
    else
        log_warning "Not running on WSL (this script works on any Ubuntu/Debian)"
        return 0
    fi
}

# Check for sudo privileges
check_sudo() {
    if sudo -n true 2>/dev/null; then
        log_success "Has sudo privileges (no password needed)"
    else
        log_info "Testing sudo access..."
        if sudo -v; then
            log_success "Has sudo privileges"
        else
            log_error "Sudo privileges required"
            exit 1
        fi
    fi
}

log_header "HGL Infrastructure Setup for WSL/Ubuntu"

echo "This script will install all necessary tools for HGL development:"
echo "  • System utilities (tree, curl, wget)"
echo "  • Git and version control tools"
echo "  • Python 3 and pip"
echo "  • OpenSSH (for signature verification)"
echo "  • JSON processing tools (jq)"
echo "  • Build tools and compilers"
echo
read -p "Continue with installation? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Installation cancelled"
    exit 0
fi

# Check environment
log_header "Checking Environment"
check_wsl
check_sudo

# Update package lists
log_header "Updating Package Lists"
log_info "This may take a few minutes..."
sudo apt update -qq

log_success "Package lists updated"

# Upgrade existing packages (optional but recommended)
log_section "Upgrade Existing Packages?"
echo "Recommended for fresh WSL installations"
read -p "Upgrade all packages? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Upgrading packages... (this may take several minutes)"
    sudo apt upgrade -y -qq
    log_success "Packages upgraded"
else
    log_info "Skipping package upgrade"
fi

# Install essential tools
log_header "Installing Essential Tools"

PACKAGES=(
    # System utilities
    "tree"              # Directory tree visualization
    "curl"              # HTTP client
    "wget"              # File downloader
    "unzip"             # Archive extraction
    "zip"               # Archive creation
    "ca-certificates"   # SSL certificates
    
    # Version control
    "git"               # Version control system
    "git-lfs"           # Git Large File Storage
    
    # Python
    "python3"           # Python 3
    "python3-pip"       # Python package manager
    "python3-venv"      # Virtual environments
    
    # Security & crypto
    "openssh-client"    # SSH client (includes ssh-keygen)
    "gnupg"             # GPG encryption
    
    # JSON/YAML processing
    "jq"                # JSON processor
    
    # Build tools
    "build-essential"   # GCC, make, etc.
    "pkg-config"        # Package configuration
    
    # Text processing
    "sed"               # Stream editor
    "awk"               # Text processing
    "grep"              # Pattern matching
    
    # Utilities
    "file"              # File type detection
    "less"              # Pager
    "nano"              # Text editor
    "vim-tiny"          # Minimal vim
)

log_info "Installing ${#PACKAGES[@]} packages..."
echo

for package in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        log_success "$package (already installed)"
    else
        log_info "Installing $package..."
        if sudo apt install -y -qq "$package" 2>&1 | grep -q "E:"; then
            log_warning "$package (failed, may already exist)"
        else
            log_success "$package"
        fi
    fi
done

# Install Python packages
log_header "Installing Python Packages"

PYTHON_PACKAGES=(
    "jsonschema"    # JSON schema validation
    "pyyaml"        # YAML processing
)

log_info "Installing ${#PYTHON_PACKAGES[@]} Python packages..."
echo

for package in "${PYTHON_PACKAGES[@]}"; do
    log_info "Installing $package..."
    if pip3 install --user "$package" -q; then
        log_success "$package"
    else
        log_warning "$package (may already be installed)"
    fi
done

# Verify installations
log_header "Verifying Installations"
echo

declare -A COMMANDS=(
    ["tree"]="tree --version"
    ["git"]="git --version"
    ["python3"]="python3 --version"
    ["pip3"]="pip3 --version"
    ["ssh-keygen"]="ssh-keygen -V"
    ["jq"]="jq --version"
    ["make"]="make --version"
    ["gcc"]="gcc --version"
    ["curl"]="curl --version"
    ["wget"]="wget --version"
)

VERIFICATION_OK=true

for cmd in "${!COMMANDS[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        version=$(${COMMANDS[$cmd]} 2>&1 | head -1 || echo "unknown")
        log_success "$cmd: $version"
    else
        log_error "$cmd: NOT FOUND"
        VERIFICATION_OK=false
    fi
done

if [[ "$VERIFICATION_OK" == false ]]; then
    echo
    log_error "Some tools failed to install"
    exit 1
fi

# Configure Git (if not already configured)
log_header "Git Configuration"

if ! git config --global user.name &> /dev/null; then
    echo
    log_warning "Git user.name not configured"
    read -p "Enter your name for Git commits: " git_name
    git config --global user.name "$git_name"
    log_success "Git user.name set to: $git_name"
else
    log_info "Git user.name: $(git config --global user.name)"
fi

if ! git config --global user.email &> /dev/null; then
    echo
    log_warning "Git user.email not configured"
    read -p "Enter your email for Git commits: " git_email
    git config --global user.email "$git_email"
    log_success "Git user.email set to: $git_email"
else
    log_info "Git user.email: $(git config --global user.email)"
fi

# Set up SSH directory
log_header "SSH Configuration"

if [[ ! -d "$HOME/.ssh" ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    log_success "Created ~/.ssh directory"
else
    log_info "~/.ssh directory exists"
fi

# Check for existing SSH keys
if ls "$HOME/.ssh/"*.pub &> /dev/null; then
    log_info "Existing SSH keys found:"
    ls -1 "$HOME/.ssh/"*.pub | while read key; do
        echo "  • $(basename "$key")"
    done
else
    log_info "No SSH keys found (you'll need to generate one for HGL signing)"
fi

# Set up Python user bin in PATH
log_header "PATH Configuration"

PYTHON_USER_BIN="$HOME/.local/bin"
if [[ -d "$PYTHON_USER_BIN" ]]; then
    if [[ ":$PATH:" != *":$PYTHON_USER_BIN:"* ]]; then
        log_warning "Python user bin not in PATH"
        echo
        log_info "Add this to your ~/.bashrc:"
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo
        read -p "Add to ~/.bashrc automatically? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo '' >> "$HOME/.bashrc"
            echo '# Python user bin' >> "$HOME/.bashrc"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            log_success "Added to ~/.bashrc (restart shell or run: source ~/.bashrc)"
        fi
    else
        log_success "Python user bin already in PATH"
    fi
fi

# Test HGL verification script (if it exists)
log_header "Testing HGL Tools"

if [[ -f "tools/verify_and_eval.sh" ]]; then
    log_info "Found verify_and_eval.sh"
    
    if [[ -x "tools/verify_and_eval.sh" ]]; then
        log_success "verify_and_eval.sh is executable"
    else
        log_warning "verify_and_eval.sh is not executable"
        chmod +x tools/verify_and_eval.sh
        log_success "Made verify_and_eval.sh executable"
    fi
    
    # Test help flag
    if tools/verify_and_eval.sh --help &> /dev/null; then
        log_success "verify_and_eval.sh runs successfully"
    else
        log_warning "verify_and_eval.sh may have issues (check dependencies)"
    fi
else
    log_info "verify_and_eval.sh not found (expected if not yet moved)"
fi

# Display summary
log_header "Installation Summary"
echo

echo "✅ Installed Tools:"
echo "  • tree, curl, wget, unzip, zip"
echo "  • git, git-lfs"
echo "  • python3, pip3"
echo "  • openssh-client (ssh-keygen)"
echo "  • jq (JSON processor)"
echo "  • build-essential (gcc, make)"
echo "  • jsonschema, pyyaml (Python packages)"
echo

echo "📋 System Information:"
echo "  • OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "  • Kernel: $(uname -r)"
echo "  • Shell: $SHELL"
echo "  • User: $USER"
echo

echo "🔧 Configuration:"
echo "  • Git user: $(git config --global user.name) <$(git config --global user.email)>"
echo "  • SSH directory: ~/.ssh"
echo "  • Python user bin: ~/.local/bin"
echo

# Next steps
log_header "Next Steps"
echo

echo "1. Restart your shell (or run: source ~/.bashrc)"
echo

echo "2. Test the installation:"
echo "   tree -L 2 tools/ .github/ docs/"
echo

echo "3. Generate an SSH key for signing (if not done):"
echo "   ssh-keygen -t ed25519 -f ~/.ssh/hgl_release_key -C \"release@helixprojectai.com\""
echo

echo "4. Update allowed_signers with your public key:"
echo "   cat ~/.ssh/hgl_release_key.pub"
echo "   nano .github/allowed_signers"
echo

echo "5. Test HGL verification:"
echo "   ./tools/verify_and_eval.sh releases/HGL-v1.2-beta.1"
echo

echo "6. Follow the deployment checklist:"
echo "   cat docs/DEPLOYMENT_CHECKLIST.md"
echo

log_success "Setup complete! 🎉"
echo

# Optional: Show helpful aliases
log_section "Optional: Add Helpful Aliases"
echo
echo "Add these to your ~/.bashrc for convenience:"
echo
cat << 'EOF'
# HGL aliases
alias hgl-verify='./tools/verify_and_eval.sh'
alias hgl-provenance='python3 tools/generate_provenance.py'
alias hgl-hashes='./tools/generate-hashes.sh'
alias hgl-tree='tree -L 2 tools/ .github/ docs/ releases/'
EOF
echo

read -p "Add these aliases to ~/.bashrc? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cat >> "$HOME/.bashrc" << 'EOF'

# HGL aliases
alias hgl-verify='./tools/verify_and_eval.sh'
alias hgl-provenance='python3 tools/generate_provenance.py'
alias hgl-hashes='./tools/generate-hashes.sh'
alias hgl-tree='tree -L 2 tools/ .github/ docs/ releases/'
EOF
    log_success "Aliases added to ~/.bashrc"
    echo "Run 'source ~/.bashrc' to use them"
fi

echo
log_info "All done! Happy coding! 🚀"
