#!/bin/bash

# Welcome-Art Quick Installation Script
# Simplified installer for fast deployment

set -e

# Script metadata
SCRIPT_NAME="Welcome-Art Quick Installer"
SCRIPT_VERSION="1.0.0"
PACKAGE_NAME="welcome-art"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Quick installation settings
FORCE_INSTALL=false
VERBOSE=false

# Print colored output
print_status() {
    local level="$1"
    local message="$2"
    
    case "$level" in
        "ERROR")
            echo -e "${RED}✗${NC} $message" >&2
            ;;
        "SUCCESS")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Error handling
quick_error() {
    local message="$1"
    print_status "ERROR" "$message"
    echo
    echo "Quick installation failed!"
    echo "For detailed installation, use: ./install.sh"
    exit 1
}

# Show usage
show_usage() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Usage: $0 [OPTIONS]

Options:
  -h, --help     Show this help message
  -f, --force    Force installation (overwrite existing)
  -v, --verbose  Show detailed output

This script performs a quick installation with minimal prompts.
For advanced options, use the full installer: ./install.sh

EOF
}

# Quick root check
quick_root_check() {
    if [[ $EUID -ne 0 ]]; then
        quick_error "Root privileges required. Run: sudo $0"
    fi
}

# Quick system check
quick_system_check() {
    print_status "INFO" "Checking system..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        quick_error "Unsupported system (no /etc/os-release)"
    fi
    
    source /etc/os-release
    
    case "$ID" in
        ubuntu|debian)
            if [[ "$VERBOSE" == "true" ]]; then
                print_status "INFO" "Detected: $PRETTY_NAME"
            fi
            ;;
        *)
            print_status "WARN" "Unsupported OS: $ID (proceeding anyway)"
            ;;
    esac
    
    # Check bash version
    if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
        quick_error "Bash 4.0+ required (found: $BASH_VERSION)"
    fi
    
    print_status "SUCCESS" "System check passed"
}

# Quick dependency check and install
quick_deps() {
    print_status "INFO" "Checking dependencies..."
    
    local missing_deps=()
    local required_deps=("figlet" "lolcat")
    
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_status "INFO" "Installing: ${missing_deps[*]}"
        
        # Quick package update and install
        if ! apt-get update >/dev/null 2>&1; then
            quick_error "Failed to update package list"
        fi
        
        if ! apt-get install -y "${missing_deps[@]}" >/dev/null 2>&1; then
            quick_error "Failed to install: ${missing_deps[*]}"
        fi
        
        print_status "SUCCESS" "Dependencies installed"
    else
        print_status "SUCCESS" "All dependencies satisfied"
    fi
}

# Quick existing installation check
quick_existing_check() {
    local existing_files=()
    
    if [[ -f "/usr/local/bin/welcome-art" ]]; then
        existing_files+=("/usr/local/bin/welcome-art")
    fi
    
    if [[ -d "/etc/welcome-art" ]]; then
        existing_files+=("/etc/welcome-art")
    fi
    
    if [[ ${#existing_files[@]} -gt 0 ]]; then
        if [[ "$FORCE_INSTALL" == "true" ]]; then
            print_status "WARN" "Overwriting existing installation"
        else
            print_status "ERROR" "Existing installation found"
            echo "Use --force to overwrite, or run: ./install.sh --uninstall"
            exit 1
        fi
    fi
}

# Quick installation
quick_install() {
    print_status "INFO" "Installing Welcome-Art..."
    
    # Get script directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Check if full installer exists
    if [[ ! -f "$script_dir/install.sh" ]]; then
        quick_error "Full installer not found: $script_dir/install.sh"
    fi
    
    # Run full installer with appropriate flags
    local install_args=("--quiet")
    
    if [[ "$FORCE_INSTALL" == "true" ]]; then
        install_args+=("--force")
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        # Remove --quiet for verbose mode
        install_args=()
        if [[ "$FORCE_INSTALL" == "true" ]]; then
            install_args+=("--force")
        fi
    fi
    
    # Execute full installer
    if "$script_dir/install.sh" "${install_args[@]}"; then
        print_status "SUCCESS" "Installation completed"
    else
        quick_error "Installation failed"
    fi
}

# Quick test
quick_test() {
    print_status "INFO" "Testing installation..."
    
    if [[ -x "/usr/local/bin/welcome-art" ]]; then
        if /usr/local/bin/welcome-art --version >/dev/null 2>&1; then
            print_status "SUCCESS" "Installation test passed"
        else
            quick_error "Installation test failed"
        fi
    else
        quick_error "Executable not found or not executable"
    fi
}

# Show quick summary
show_quick_summary() {
    echo
    echo -e "${GREEN}🎉 Welcome-Art installed successfully!${NC}"
    echo "====================================="
    echo
    echo "Quick start:"
    echo "  welcome-art              # Show welcome art"
    echo "  welcome-art list         # List templates"
    echo "  welcome-art --help       # Show help"
    echo
    echo "Auto-execution is enabled for SSH logins."
    echo "Log out and back in to see it in action!"
    echo
    echo "For configuration: welcome-art config --user"
    echo "For support: https://github.com/welcome-art/welcome-art"
    echo
}

# Parse arguments
parse_quick_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -f|--force)
                FORCE_INSTALL=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information." >&2
                exit 1
                ;;
        esac
    done
}

# Main quick installation function
main() {
    # Parse arguments
    parse_quick_args "$@"
    
    # Show header
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "================================"
    echo
    
    # Quick installation steps
    quick_root_check
    quick_system_check
    quick_existing_check
    quick_deps
    quick_install
    quick_test
    show_quick_summary
    
    echo "Quick installation completed in $(date)!"
}

# Trap errors
trap 'quick_error "Unexpected error occurred"' ERR

# Run main function
main "$@"