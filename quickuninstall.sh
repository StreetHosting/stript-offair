#!/bin/bash

# Welcome-Art Quick Uninstallation Script
# Simplified uninstaller for fast removal

set -e

# Script metadata
SCRIPT_NAME="Welcome-Art Quick Uninstaller"
SCRIPT_VERSION="1.0.0"
PACKAGE_NAME="welcome-art"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Quick uninstallation settings
FORCE_REMOVE=false
PURGE_USER_DATA=false
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
    echo "Quick uninstallation failed!"
    echo "For detailed removal, use: ./install.sh --uninstall"
    exit 1
}

# Show usage
show_usage() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Usage: $0 [OPTIONS]

Options:
  -h, --help     Show this help message
  -f, --force    Force removal (no confirmation)
  -p, --purge    Remove user data and configurations
  -v, --verbose  Show detailed output

This script performs a quick uninstallation with minimal prompts.
For advanced options, use: ./install.sh --uninstall

EOF
}

# Quick root check
quick_root_check() {
    if [[ $EUID -ne 0 ]]; then
        quick_error "Root privileges required. Run: sudo $0"
    fi
}

# Quick installation check
quick_installation_check() {
    print_status "INFO" "Checking installation..."
    
    local found_files=()
    
    if [[ -f "/usr/local/bin/welcome-art" ]]; then
        found_files+=("/usr/local/bin/welcome-art")
    fi
    
    if [[ -d "/etc/welcome-art" ]]; then
        found_files+=("/etc/welcome-art")
    fi
    
    if [[ -f "/etc/profile.d/welcome-art.sh" ]]; then
        found_files+=("/etc/profile.d/welcome-art.sh")
    fi
    
    if [[ ${#found_files[@]} -eq 0 ]]; then
        print_status "WARN" "No installation found"
        echo "Welcome-Art does not appear to be installed."
        exit 0
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_status "INFO" "Found: ${found_files[*]}"
    fi
    
    print_status "SUCCESS" "Installation detected"
}

# Quick confirmation
quick_confirm() {
    if [[ "$FORCE_REMOVE" == "true" ]]; then
        return 0
    fi
    
    echo
    print_status "WARN" "This will remove Welcome-Art from your system"
    
    if [[ "$PURGE_USER_DATA" == "true" ]]; then
        print_status "WARN" "User data and configurations will also be removed"
    fi
    
    echo
    read -p "Continue with uninstallation? [y/N]: " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "INFO" "Uninstallation cancelled"
        exit 0
    fi
}

# Quick backup user data
quick_backup() {
    if [[ "$PURGE_USER_DATA" == "true" ]]; then
        return 0  # Skip backup if purging
    fi
    
    print_status "INFO" "Backing up user configurations..."
    
    local backup_dir="/tmp/welcome-art-backup-$(date +%Y%m%d-%H%M%S)"
    local backed_up=false
    
    # Create backup directory
    if ! mkdir -p "$backup_dir"; then
        print_status "WARN" "Failed to create backup directory"
        return 0
    fi
    
    # Backup user configs
    for user_home in /home/*; do
        if [[ -d "$user_home" && -f "$user_home/.welcome-artrc" ]]; then
            local username="$(basename "$user_home")"
            if cp "$user_home/.welcome-artrc" "$backup_dir/${username}-welcome-artrc" 2>/dev/null; then
                backed_up=true
                if [[ "$VERBOSE" == "true" ]]; then
                    print_status "INFO" "Backed up config for: $username"
                fi
            fi
        fi
    done
    
    # Backup root config if exists
    if [[ -f "/root/.welcome-artrc" ]]; then
        if cp "/root/.welcome-artrc" "$backup_dir/root-welcome-artrc" 2>/dev/null; then
            backed_up=true
            if [[ "$VERBOSE" == "true" ]]; then
                print_status "INFO" "Backed up root config"
            fi
        fi
    fi
    
    if [[ "$backed_up" == "true" ]]; then
        print_status "SUCCESS" "Configurations backed up to: $backup_dir"
    else
        # Remove empty backup directory
        rmdir "$backup_dir" 2>/dev/null || true
        if [[ "$VERBOSE" == "true" ]]; then
            print_status "INFO" "No user configurations found to backup"
        fi
    fi
}

# Quick removal
quick_remove() {
    print_status "INFO" "Removing Welcome-Art..."
    
    # Get script directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Check if full installer exists
    if [[ ! -f "$script_dir/install.sh" ]]; then
        # Manual removal if installer not available
        quick_manual_remove
        return
    fi
    
    # Run full installer uninstall with appropriate flags
    local uninstall_args=("--uninstall" "--quiet")
    
    if [[ "$FORCE_REMOVE" == "true" ]]; then
        uninstall_args+=("--force")
    fi
    
    if [[ "$PURGE_USER_DATA" == "true" ]]; then
        uninstall_args+=("--purge")
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        # Remove --quiet for verbose mode
        uninstall_args=("--uninstall")
        if [[ "$FORCE_REMOVE" == "true" ]]; then
            uninstall_args+=("--force")
        fi
        if [[ "$PURGE_USER_DATA" == "true" ]]; then
            uninstall_args+=("--purge")
        fi
    fi
    
    # Execute full installer uninstall
    if "$script_dir/install.sh" "${uninstall_args[@]}"; then
        print_status "SUCCESS" "Removal completed"
    else
        quick_error "Removal failed"
    fi
}

# Manual removal fallback
quick_manual_remove() {
    print_status "INFO" "Performing manual removal..."
    
    local removed_items=()
    
    # Remove main executable
    if [[ -f "/usr/local/bin/welcome-art" ]]; then
        if rm -f "/usr/local/bin/welcome-art" 2>/dev/null; then
            removed_items+=("/usr/local/bin/welcome-art")
        fi
    fi
    
    # Remove system configuration
    if [[ -d "/etc/welcome-art" ]]; then
        if rm -rf "/etc/welcome-art" 2>/dev/null; then
            removed_items+=("/etc/welcome-art")
        fi
    fi
    
    # Remove profile script
    if [[ -f "/etc/profile.d/welcome-art.sh" ]]; then
        if rm -f "/etc/profile.d/welcome-art.sh" 2>/dev/null; then
            removed_items+=("/etc/profile.d/welcome-art.sh")
        fi
    fi
    
    # Remove user data if requested
    if [[ "$PURGE_USER_DATA" == "true" ]]; then
        for user_home in /home/* /root; do
            if [[ -f "$user_home/.welcome-artrc" ]]; then
                if rm -f "$user_home/.welcome-artrc" 2>/dev/null; then
                    removed_items+=("$user_home/.welcome-artrc")
                fi
            fi
        done
    fi
    
    if [[ ${#removed_items[@]} -gt 0 ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            print_status "SUCCESS" "Removed: ${removed_items[*]}"
        else
            print_status "SUCCESS" "Removed ${#removed_items[@]} items"
        fi
    else
        print_status "WARN" "No items removed"
    fi
}

# Quick verification
quick_verify() {
    print_status "INFO" "Verifying removal..."
    
    local remaining_files=()
    
    if [[ -f "/usr/local/bin/welcome-art" ]]; then
        remaining_files+=("/usr/local/bin/welcome-art")
    fi
    
    if [[ -d "/etc/welcome-art" ]]; then
        remaining_files+=("/etc/welcome-art")
    fi
    
    if [[ -f "/etc/profile.d/welcome-art.sh" ]]; then
        remaining_files+=("/etc/profile.d/welcome-art.sh")
    fi
    
    if [[ ${#remaining_files[@]} -gt 0 ]]; then
        print_status "WARN" "Some files remain: ${remaining_files[*]}"
        print_status "INFO" "Manual cleanup may be required"
    else
        print_status "SUCCESS" "Removal verification passed"
    fi
}

# Show quick summary
show_quick_summary() {
    echo
    echo -e "${GREEN}🗑️  Welcome-Art removed successfully!${NC}"
    echo "===================================="
    echo
    
    if [[ "$PURGE_USER_DATA" != "true" ]]; then
        echo "User configurations were preserved."
        echo "Check /tmp/welcome-art-backup-* for backups."
        echo
    fi
    
    echo "To reinstall: ./quickinstall.sh"
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
                FORCE_REMOVE=true
                shift
                ;;
            -p|--purge)
                PURGE_USER_DATA=true
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

# Main quick uninstallation function
main() {
    # Parse arguments
    parse_quick_args "$@"
    
    # Show header
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "==================================="
    echo
    
    # Quick uninstallation steps
    quick_root_check
    quick_installation_check
    quick_confirm
    quick_backup
    quick_remove
    quick_verify
    show_quick_summary
    
    echo "Quick uninstallation completed in $(date)!"
}

# Trap errors
trap 'quick_error "Unexpected error occurred"' ERR

# Run main function
main "$@"