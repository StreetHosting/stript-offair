#!/bin/bash

# Welcome-Art Installation Script
# Comprehensive installer with dependency management and error handling

set -e

# Script metadata
SCRIPT_NAME="Welcome-Art Installer"
SCRIPT_VERSION="1.0.0"
PACKAGE_NAME="welcome-art"
PACKAGE_VERSION="1.0.0"

# Installation paths
INSTALL_PREFIX="/usr/local"
SYSTEM_CONFIG_DIR="/etc/welcome-art"
WELCOME_ART_BIN="$INSTALL_PREFIX/bin/welcome-art"
PROFILE_SCRIPT="/etc/profile.d/welcome-art.sh"
LOG_FILE="/var/log/welcome-art-install.log"

# Source directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation options
FORCE_INSTALL=false
SKIP_DEPS=false
QUIET_MODE=false
DRY_RUN=false
UNINSTALL_MODE=false

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    
    # Log to console unless quiet
    if [[ "$QUIET_MODE" != "true" ]]; then
        case "$level" in
            "ERROR")
                echo -e "${RED}[ERROR]${NC} $message" >&2
                ;;
            "WARN")
                echo -e "${YELLOW}[WARN]${NC} $message"
                ;;
            "INFO")
                echo -e "${GREEN}[INFO]${NC} $message"
                ;;
            "DEBUG")
                echo -e "${BLUE}[DEBUG]${NC} $message"
                ;;
            *)
                echo "[$level] $message"
                ;;
        esac
    fi
}

# Error handling
error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log_message "ERROR" "$message"
    echo
    echo -e "${RED}Installation failed!${NC}"
    echo "Check the log file for details: $LOG_FILE"
    exit "$exit_code"
}

# Show usage information
show_usage() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

Usage: $0 [OPTIONS]

Options:
  -h, --help          Show this help message
  -v, --version       Show version information
  -f, --force         Force installation (overwrite existing files)
  -s, --skip-deps     Skip dependency installation
  -q, --quiet         Quiet mode (minimal output)
  -n, --dry-run       Show what would be done without actually doing it
  -u, --uninstall     Uninstall Welcome-Art
  --prefix PATH       Installation prefix (default: $INSTALL_PREFIX)
  --config-dir PATH   Configuration directory (default: $SYSTEM_CONFIG_DIR)

Examples:
  $0                  # Standard installation
  $0 --force          # Force reinstallation
  $0 --skip-deps      # Install without checking dependencies
  $0 --uninstall      # Remove Welcome-Art
  $0 --dry-run        # Preview installation steps

For more information, visit:
  https://github.com/welcome-art/welcome-art

EOF
}

# Show version information
show_version() {
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "Package: $PACKAGE_NAME v$PACKAGE_VERSION"
    echo "Compatible with: Ubuntu 18.04+, Debian 9+"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root. Use: sudo $0"
    fi
}

# Check system compatibility
check_system() {
    log_message "INFO" "Checking system compatibility..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        error_exit "Cannot determine operating system. /etc/os-release not found."
    fi
    
    source /etc/os-release
    
    case "$ID" in
        ubuntu)
            if [[ "${VERSION_ID%%.*}" -lt 18 ]]; then
                error_exit "Ubuntu 18.04 or later is required. Found: $VERSION_ID"
            fi
            ;;
        debian)
            if [[ "${VERSION_ID%%.*}" -lt 9 ]]; then
                error_exit "Debian 9 or later is required. Found: $VERSION_ID"
            fi
            ;;
        *)
            log_message "WARN" "Unsupported OS: $ID $VERSION_ID. Installation may not work correctly."
            ;;
    esac
    
    # Check architecture
    local arch=$(uname -m)
    case "$arch" in
        x86_64|amd64|i386|i686|armv7l|aarch64)
            log_message "INFO" "Architecture supported: $arch"
            ;;
        *)
            log_message "WARN" "Unsupported architecture: $arch. Installation may not work correctly."
            ;;
    esac
    
    # Check bash version
    if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
        error_exit "Bash 4.0 or later is required. Found: $BASH_VERSION"
    fi
    
    log_message "INFO" "System compatibility check passed"
}

# Check and install dependencies
check_dependencies() {
    if [[ "$SKIP_DEPS" == "true" ]]; then
        log_message "INFO" "Skipping dependency check as requested"
        return 0
    fi
    
    log_message "INFO" "Checking dependencies..."
    
    local missing_deps=()
    local missing_optional=()
    
    # Required dependencies
    local required_deps=("figlet" "lolcat" "bash")
    
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    # Optional dependencies
    local optional_deps=("git" "wget" "unzip" "curl")
    
    for dep in "${optional_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_optional+=("$dep")
        fi
    done
    
    # Install missing required dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_message "INFO" "Installing missing required dependencies: ${missing_deps[*]}"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY RUN] Would install: ${missing_deps[*]}"
        else
            # Update package list
            if ! apt-get update >/dev/null 2>&1; then
                error_exit "Failed to update package list"
            fi
            
            # Install dependencies
            if ! apt-get install -y "${missing_deps[@]}" >/dev/null 2>&1; then
                error_exit "Failed to install required dependencies: ${missing_deps[*]}"
            fi
            
            log_message "INFO" "Required dependencies installed successfully"
        fi
    else
        log_message "INFO" "All required dependencies are already installed"
    fi
    
    # Report optional dependencies
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_message "INFO" "Optional dependencies not installed: ${missing_optional[*]}"
        log_message "INFO" "These can be installed later for enhanced functionality"
    fi
}

# Check for existing installation
check_existing_installation() {
    log_message "INFO" "Checking for existing installation..."
    
    local existing_files=()
    
    # Check for existing files
    if [[ -f "$WELCOME_ART_BIN" ]]; then
        existing_files+=("$WELCOME_ART_BIN")
    fi
    
    if [[ -d "$SYSTEM_CONFIG_DIR" ]]; then
        existing_files+=("$SYSTEM_CONFIG_DIR")
    fi
    
    if [[ -f "$PROFILE_SCRIPT" ]]; then
        existing_files+=("$PROFILE_SCRIPT")
    fi
    
    if [[ ${#existing_files[@]} -gt 0 ]]; then
        if [[ "$FORCE_INSTALL" == "true" ]]; then
            log_message "WARN" "Existing installation found. Force mode enabled - will overwrite."
            log_message "INFO" "Existing files: ${existing_files[*]}"
        else
            log_message "ERROR" "Existing installation found: ${existing_files[*]}"
            echo
            echo "Use --force to overwrite existing installation, or --uninstall to remove first."
            exit 1
        fi
    else
        log_message "INFO" "No existing installation found"
    fi
}

# Create directories
create_directories() {
    log_message "INFO" "Creating directories..."
    
    local directories=(
        "$SYSTEM_CONFIG_DIR"
        "$SYSTEM_CONFIG_DIR/art"
        "$SYSTEM_CONFIG_DIR/scripts"
        "$(dirname "$WELCOME_ART_BIN")"
        "$(dirname "$LOG_FILE")"
    )
    
    for dir in "${directories[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY RUN] Would create directory: $dir"
        else
            if mkdir -p "$dir" 2>/dev/null; then
                log_message "DEBUG" "Created directory: $dir"
            else
                error_exit "Failed to create directory: $dir"
            fi
        fi
    done
}

# Install files
install_files() {
    log_message "INFO" "Installing files..."
    
    # File mappings: source -> destination
    declare -A file_mappings=(
        ["usr/local/bin/welcome-art"]="$WELCOME_ART_BIN"
        ["etc/welcome-art/config"]="$SYSTEM_CONFIG_DIR/config"
        ["etc/welcome-art/welcome-artrc.template"]="$SYSTEM_CONFIG_DIR/welcome-artrc.template"
        ["etc/welcome-art/art/default.art"]="$SYSTEM_CONFIG_DIR/art/default.art"
        ["etc/welcome-art/art/modern.art"]="$SYSTEM_CONFIG_DIR/art/modern.art"
        ["etc/welcome-art/art/classic.art"]="$SYSTEM_CONFIG_DIR/art/classic.art"
        ["etc/welcome-art/scripts/update.sh"]="$SYSTEM_CONFIG_DIR/scripts/update.sh"
        ["etc/welcome-art/scripts/config.sh"]="$SYSTEM_CONFIG_DIR/scripts/config.sh"
        ["etc/welcome-art/scripts/list.sh"]="$SYSTEM_CONFIG_DIR/scripts/list.sh"
        ["etc/welcome-art/scripts/set.sh"]="$SYSTEM_CONFIG_DIR/scripts/set.sh"
        ["etc/profile.d/welcome-art.sh"]="$PROFILE_SCRIPT"
    )
    
    for source_file in "${!file_mappings[@]}"; do
        local source_path="$SOURCE_DIR/$source_file"
        local dest_path="${file_mappings[$source_file]}"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY RUN] Would install: $source_path -> $dest_path"
            continue
        fi
        
        if [[ ! -f "$source_path" ]]; then
            error_exit "Source file not found: $source_path"
        fi
        
        # Create destination directory if needed
        local dest_dir="$(dirname "$dest_path")"
        mkdir -p "$dest_dir" 2>/dev/null || error_exit "Failed to create directory: $dest_dir"
        
        # Copy file
        if cp "$source_path" "$dest_path" 2>/dev/null; then
            log_message "DEBUG" "Installed: $source_path -> $dest_path"
        else
            error_exit "Failed to install file: $source_path -> $dest_path"
        fi
    done
    
    log_message "INFO" "Files installed successfully"
}

# Set file permissions
set_permissions() {
    log_message "INFO" "Setting file permissions..."
    
    # Executable files
    local executables=(
        "$WELCOME_ART_BIN"
        "$SYSTEM_CONFIG_DIR/scripts/update.sh"
        "$SYSTEM_CONFIG_DIR/scripts/config.sh"
        "$SYSTEM_CONFIG_DIR/scripts/list.sh"
        "$SYSTEM_CONFIG_DIR/scripts/set.sh"
    )
    
    for executable in "${executables[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY RUN] Would set executable: $executable"
        else
            if [[ -f "$executable" ]]; then
                chmod 755 "$executable" || error_exit "Failed to set permissions: $executable"
                chown root:root "$executable" || error_exit "Failed to set ownership: $executable"
                log_message "DEBUG" "Set executable permissions: $executable"
            fi
        fi
    done
    
    # Configuration files
    local config_files=(
        "$SYSTEM_CONFIG_DIR/config"
        "$SYSTEM_CONFIG_DIR/welcome-artrc.template"
        "$PROFILE_SCRIPT"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY RUN] Would set config permissions: $config_file"
        else
            if [[ -f "$config_file" ]]; then
                chmod 644 "$config_file" || error_exit "Failed to set permissions: $config_file"
                chown root:root "$config_file" || error_exit "Failed to set ownership: $config_file"
                log_message "DEBUG" "Set config permissions: $config_file"
            fi
        fi
    done
    
    # Art templates
    if [[ -d "$SYSTEM_CONFIG_DIR/art" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY RUN] Would set art template permissions"
        else
            find "$SYSTEM_CONFIG_DIR/art" -name "*.art" -type f -exec chmod 644 {} \; || error_exit "Failed to set art template permissions"
            find "$SYSTEM_CONFIG_DIR/art" -name "*.art" -type f -exec chown root:root {} \; || error_exit "Failed to set art template ownership"
            log_message "DEBUG" "Set art template permissions"
        fi
    fi
    
    log_message "INFO" "File permissions set successfully"
}

# Test installation
test_installation() {
    log_message "INFO" "Testing installation..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would test installation"
        return 0
    fi
    
    # Test main executable
    if [[ ! -x "$WELCOME_ART_BIN" ]]; then
        error_exit "Main executable not found or not executable: $WELCOME_ART_BIN"
    fi
    
    # Test version command
    if ! "$WELCOME_ART_BIN" --version >/dev/null 2>&1; then
        error_exit "Main executable test failed"
    fi
    
    # Test help command
    if ! "$WELCOME_ART_BIN" --help >/dev/null 2>&1; then
        error_exit "Help command test failed"
    fi
    
    # Test configuration loading
    if [[ ! -f "$SYSTEM_CONFIG_DIR/config" ]]; then
        error_exit "System configuration file not found: $SYSTEM_CONFIG_DIR/config"
    fi
    
    # Test art templates
    local template_count=$(find "$SYSTEM_CONFIG_DIR/art" -name "*.art" -type f | wc -l)
    if [[ "$template_count" -eq 0 ]]; then
        error_exit "No art templates found in: $SYSTEM_CONFIG_DIR/art"
    fi
    
    log_message "INFO" "Installation test passed"
}

# Show installation summary
show_summary() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo
        echo "[DRY RUN] Installation preview completed"
        echo "Run without --dry-run to perform actual installation"
        return 0
    fi
    
    echo
    echo -e "${GREEN}Welcome-Art installation completed successfully!${NC}"
    echo "================================================"
    echo
    echo "Installation details:"
    echo "  Package: $PACKAGE_NAME v$PACKAGE_VERSION"
    echo "  Executable: $WELCOME_ART_BIN"
    echo "  Configuration: $SYSTEM_CONFIG_DIR"
    echo "  Auto-execution: $PROFILE_SCRIPT"
    echo
    echo "Usage:"
    echo "  welcome-art                    # Display welcome art"
    echo "  welcome-art list               # List available templates"
    echo "  welcome-art set template NAME  # Set active template"
    echo "  welcome-art config --user      # Edit user configuration"
    echo "  welcome-art update             # Update templates"
    echo "  welcome-art --help             # Show help"
    echo
    echo "Next steps:"
    echo "  1. Log out and log back in to see Welcome-Art on SSH login"
    echo "  2. Customize your configuration: welcome-art config --user"
    echo "  3. Explore templates: welcome-art list"
    echo "  4. Set your favorite template: welcome-art set template <name>"
    echo
    echo "For support and documentation:"
    echo "  https://github.com/welcome-art/welcome-art"
    echo
}

# Uninstall function
uninstall() {
    log_message "INFO" "Starting uninstallation..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would uninstall Welcome-Art"
        return 0
    fi
    
    # Remove files
    local files_to_remove=(
        "$WELCOME_ART_BIN"
        "$PROFILE_SCRIPT"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [[ -f "$file" ]]; then
            if rm -f "$file" 2>/dev/null; then
                log_message "INFO" "Removed: $file"
            else
                log_message "WARN" "Failed to remove: $file"
            fi
        fi
    done
    
    # Remove configuration directory
    if [[ -d "$SYSTEM_CONFIG_DIR" ]]; then
        if rm -rf "$SYSTEM_CONFIG_DIR" 2>/dev/null; then
            log_message "INFO" "Removed configuration directory: $SYSTEM_CONFIG_DIR"
        else
            log_message "WARN" "Failed to remove configuration directory: $SYSTEM_CONFIG_DIR"
        fi
    fi
    
    echo
    echo -e "${GREEN}Welcome-Art uninstalled successfully!${NC}"
    echo "User configurations (~/.welcome-artrc) were preserved."
    echo
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -f|--force)
                FORCE_INSTALL=true
                shift
                ;;
            -s|--skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -u|--uninstall)
                UNINSTALL_MODE=true
                shift
                ;;
            --prefix)
                INSTALL_PREFIX="$2"
                WELCOME_ART_BIN="$INSTALL_PREFIX/bin/welcome-art"
                shift 2
                ;;
            --config-dir)
                SYSTEM_CONFIG_DIR="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information." >&2
                exit 1
                ;;
        esac
    done
}

# Main installation function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    # Show header
    if [[ "$QUIET_MODE" != "true" ]]; then
        echo "$SCRIPT_NAME v$SCRIPT_VERSION"
        echo "=============================="
        echo
    fi
    
    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || true
    
    log_message "INFO" "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    log_message "INFO" "Command line: $0 $*"
    
    # Handle uninstall mode
    if [[ "$UNINSTALL_MODE" == "true" ]]; then
        check_root
        uninstall
        exit 0
    fi
    
    # Standard installation
    check_root
    check_system
    check_dependencies
    check_existing_installation
    create_directories
    install_files
    set_permissions
    test_installation
    show_summary
    
    log_message "INFO" "Installation completed successfully"
}

# Run main function with all arguments
main "$@"