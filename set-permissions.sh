#!/bin/bash

# Welcome-Art File Permissions Setup Script
# Sets proper permissions and ownership for all package files

set -e

# Script metadata
SCRIPT_NAME="Welcome-Art Permissions Setup"
SCRIPT_VERSION="1.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Settings
VERBOSE=false
DRY_RUN=false

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
perms_error() {
    local message="$1"
    print_status "ERROR" "$message"
    exit 1
}

# Show usage
show_usage() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Usage: $0 [OPTIONS]

Options:
  -h, --help     Show this help message
  -v, --verbose  Show detailed output
  -n, --dry-run  Show what would be done without making changes

This script sets proper file permissions and ownership for Welcome-Art
according to the technical specifications.

EOF
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        perms_error "Root privileges required. Run: sudo $0"
    fi
}

# Execute command with dry-run support
exec_cmd() {
    local cmd="$1"
    local description="$2"
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_status "INFO" "$description"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] $cmd"
        return 0
    fi
    
    if eval "$cmd" 2>/dev/null; then
        if [[ "$VERBOSE" == "true" ]]; then
            print_status "SUCCESS" "$description"
        fi
        return 0
    else
        print_status "WARN" "Failed: $description"
        return 1
    fi
}

# Set permissions for a file/directory
set_perms() {
    local path="$1"
    local perms="$2"
    local owner="$3"
    local description="$4"
    
    if [[ ! -e "$path" ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            print_status "WARN" "Path not found: $path"
        fi
        return 1
    fi
    
    # Set ownership
    if [[ -n "$owner" ]]; then
        exec_cmd "chown $owner '$path'" "Set owner $owner for $description"
    fi
    
    # Set permissions
    if [[ -n "$perms" ]]; then
        exec_cmd "chmod $perms '$path'" "Set permissions $perms for $description"
    fi
}

# Set permissions recursively
set_perms_recursive() {
    local path="$1"
    local dir_perms="$2"
    local file_perms="$3"
    local owner="$4"
    local description="$5"
    
    if [[ ! -d "$path" ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            print_status "WARN" "Directory not found: $path"
        fi
        return 1
    fi
    
    # Set ownership recursively
    if [[ -n "$owner" ]]; then
        exec_cmd "chown -R $owner '$path'" "Set recursive owner $owner for $description"
    fi
    
    # Set directory permissions
    if [[ -n "$dir_perms" ]]; then
        exec_cmd "find '$path' -type d -exec chmod $dir_perms {} +" "Set directory permissions $dir_perms for $description"
    fi
    
    # Set file permissions
    if [[ -n "$file_perms" ]]; then
        exec_cmd "find '$path' -type f -exec chmod $file_perms {} +" "Set file permissions $file_perms for $description"
    fi
}

# Set executable permissions
set_executable() {
    local path="$1"
    local description="$2"
    
    set_perms "$path" "755" "root:root" "$description"
}

# Set configuration permissions
set_config() {
    local path="$1"
    local description="$2"
    
    set_perms "$path" "644" "root:root" "$description"
}

# Set script permissions
set_script() {
    local path="$1"
    local description="$2"
    
    set_perms "$path" "755" "root:root" "$description"
}

# Main permissions setup
setup_permissions() {
    print_status "INFO" "Setting up Welcome-Art file permissions..."
    
    local errors=0
    
    # Main executable
    if ! set_executable "/usr/local/bin/welcome-art" "main executable"; then
        ((errors++))
    fi
    
    # System configuration directory
    if ! set_perms_recursive "/etc/welcome-art" "755" "644" "root:root" "system configuration directory"; then
        ((errors++))
    fi
    
    # Configuration files
    if ! set_config "/etc/welcome-art/config" "system configuration file"; then
        ((errors++))
    fi
    
    if ! set_config "/etc/welcome-art/welcome-artrc.template" "user configuration template"; then
        ((errors++))
    fi
    
    # Art templates directory
    if ! set_perms_recursive "/etc/welcome-art/art" "755" "644" "root:root" "art templates directory"; then
        ((errors++))
    fi
    
    # Subcommand scripts
    local scripts=(
        "/etc/welcome-art/scripts/update.sh"
        "/etc/welcome-art/scripts/config.sh"
        "/etc/welcome-art/scripts/list.sh"
        "/etc/welcome-art/scripts/set.sh"
    )
    
    for script in "${scripts[@]}"; do
        if ! set_script "$script" "subcommand script $(basename "$script")"; then
            ((errors++))
        fi
    done
    
    # Profile script
    if ! set_script "/etc/profile.d/welcome-art.sh" "profile script"; then
        ((errors++))
    fi
    
    # Installation scripts (if present)
    local install_scripts=(
        "./install.sh"
        "./quickinstall.sh"
        "./quickuninstall.sh"
        "./set-permissions.sh"
    )
    
    for script in "${install_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if ! set_script "$script" "installation script $(basename "$script")"; then
                ((errors++))
            fi
        fi
    done
    
    # DEBIAN package files (if present)
    local debian_files=(
        "./DEBIAN/control"
        "./DEBIAN/postinst"
        "./DEBIAN/prerm"
        "./DEBIAN/postrm"
    )
    
    for file in "${debian_files[@]}"; do
        if [[ -f "$file" ]]; then
            if [[ "$file" =~ \.(postinst|prerm|postrm)$ ]]; then
                # Maintainer scripts need execute permissions
                if ! set_script "$file" "DEBIAN maintainer script $(basename "$file")"; then
                    ((errors++))
                fi
            else
                # Control files are read-only
                if ! set_config "$file" "DEBIAN control file $(basename "$file")"; then
                    ((errors++))
                fi
            fi
        fi
    done
    
    # Log directory (create if needed)
    local log_dir="/var/log/welcome-art"
    if [[ ! -d "$log_dir" ]]; then
        exec_cmd "mkdir -p '$log_dir'" "Create log directory"
    fi
    
    if ! set_perms "$log_dir" "755" "root:root" "log directory"; then
        ((errors++))
    fi
    
    # Cache directory (create if needed)
    local cache_dir="/var/cache/welcome-art"
    if [[ ! -d "$cache_dir" ]]; then
        exec_cmd "mkdir -p '$cache_dir'" "Create cache directory"
    fi
    
    if ! set_perms "$cache_dir" "755" "root:root" "cache directory"; then
        ((errors++))
    fi
    
    # Report results
    if [[ $errors -eq 0 ]]; then
        print_status "SUCCESS" "All permissions set successfully"
    else
        print_status "WARN" "Completed with $errors errors/warnings"
    fi
    
    return $errors
}

# Verify permissions
verify_permissions() {
    print_status "INFO" "Verifying file permissions..."
    
    local issues=0
    
    # Check main executable
    if [[ -f "/usr/local/bin/welcome-art" ]]; then
        local perms=$(stat -c "%a" "/usr/local/bin/welcome-art" 2>/dev/null || echo "000")
        if [[ "$perms" != "755" ]]; then
            print_status "WARN" "Main executable has incorrect permissions: $perms (expected: 755)"
            ((issues++))
        fi
    else
        print_status "WARN" "Main executable not found"
        ((issues++))
    fi
    
    # Check configuration directory
    if [[ -d "/etc/welcome-art" ]]; then
        local perms=$(stat -c "%a" "/etc/welcome-art" 2>/dev/null || echo "000")
        if [[ "$perms" != "755" ]]; then
            print_status "WARN" "Configuration directory has incorrect permissions: $perms (expected: 755)"
            ((issues++))
        fi
    else
        print_status "WARN" "Configuration directory not found"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        print_status "SUCCESS" "Permission verification passed"
    else
        print_status "WARN" "Found $issues permission issues"
    fi
    
    return $issues
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                VERBOSE=true  # Enable verbose for dry-run
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

# Main function
main() {
    # Parse arguments
    parse_args "$@"
    
    # Show header
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "=============================="
    echo
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "INFO" "DRY-RUN MODE: No changes will be made"
        echo
    fi
    
    # Check root privileges
    if [[ "$DRY_RUN" != "true" ]]; then
        check_root
    fi
    
    # Setup permissions
    if setup_permissions; then
        echo
        verify_permissions
        echo
        print_status "SUCCESS" "Permissions setup completed"
    else
        echo
        print_status "ERROR" "Permissions setup failed"
        exit 1
    fi
}

# Run main function
main "$@"