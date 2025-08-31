#!/bin/bash

# Welcome-Art Update Subcommand
# Downloads and updates art templates from repository

set -euo pipefail

# Configuration
SCRIPT_NAME="welcome-art update"
SYSTEM_CONFIG_DIR="/etc/welcome-art"
SYSTEM_CONFIG_FILE="$SYSTEM_CONFIG_DIR/config"
ART_DIR="$SYSTEM_CONFIG_DIR/art"
LOG_FILE="/var/log/welcome-art.log"
TEMP_DIR="/tmp/welcome-art-update"

# Default repository URL
DEFAULT_REPO_URL="https://github.com/welcome-art/templates"

# Exit codes
EXIT_SUCCESS=0
EXIT_GENERAL_ERROR=1
EXIT_NETWORK_ERROR=2
EXIT_PERMISSION_DENIED=5

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -w "$(dirname "$LOG_FILE")" ]] 2>/dev/null; then
        echo "[$timestamp] [$level] [UPDATE] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Error handling
error_exit() {
    local message="$1"
    local exit_code="${2:-$EXIT_GENERAL_ERROR}"
    
    echo "Error: $message" >&2
    log_message "ERROR" "$message"
    exit "$exit_code"
}

# Parse configuration to get repository URL
get_repo_url() {
    local repo_url="$DEFAULT_REPO_URL"
    
    if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/^"\|"$//g')
            
            if [[ "$key" == "repository_url" ]]; then
                repo_url="$value"
                break
            fi
        done < "$SYSTEM_CONFIG_FILE"
    fi
    
    echo "$repo_url"
}

# Check if we have write permissions to art directory
check_permissions() {
    if [[ ! -w "$ART_DIR" ]]; then
        error_exit "No write permission to $ART_DIR. Run as root or with sudo." "$EXIT_PERMISSION_DENIED"
    fi
}

# Download templates from repository
download_templates() {
    local repo_url="$1"
    local force_update="${2:-false}"
    
    echo "Updating art templates from: $repo_url"
    log_message "INFO" "Starting template update from $repo_url"
    
    # Create temporary directory
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Check if git is available
    if command -v git >/dev/null 2>&1; then
        # Use git to clone repository
        if git clone "$repo_url" "$TEMP_DIR/repo" 2>/dev/null; then
            local templates_dir="$TEMP_DIR/repo/templates"
            if [[ -d "$templates_dir" ]]; then
                install_templates "$templates_dir" "$force_update"
            else
                # Try root directory if templates subdirectory doesn't exist
                install_templates "$TEMP_DIR/repo" "$force_update"
            fi
        else
            error_exit "Failed to clone repository: $repo_url" "$EXIT_NETWORK_ERROR"
        fi
    elif command -v wget >/dev/null 2>&1; then
        # Fallback to wget for GitHub repositories
        local archive_url
        if [[ "$repo_url" =~ github\.com ]]; then
            archive_url="${repo_url}/archive/main.zip"
            if wget -q "$archive_url" -O "$TEMP_DIR/templates.zip"; then
                if command -v unzip >/dev/null 2>&1; then
                    unzip -q "$TEMP_DIR/templates.zip" -d "$TEMP_DIR"
                    local extracted_dir=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "*-main" | head -1)
                    if [[ -n "$extracted_dir" ]]; then
                        install_templates "$extracted_dir/templates" "$force_update" || install_templates "$extracted_dir" "$force_update"
                    fi
                else
                    error_exit "unzip command not found. Please install unzip or git." "$EXIT_GENERAL_ERROR"
                fi
            else
                error_exit "Failed to download templates from: $archive_url" "$EXIT_NETWORK_ERROR"
            fi
        else
            error_exit "Unsupported repository URL format: $repo_url" "$EXIT_GENERAL_ERROR"
        fi
    else
        error_exit "Neither git nor wget found. Please install one of them." "$EXIT_GENERAL_ERROR"
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
}

# Install templates from downloaded directory
install_templates() {
    local source_dir="$1"
    local force_update="$2"
    local installed_count=0
    local updated_count=0
    
    if [[ ! -d "$source_dir" ]]; then
        error_exit "Templates directory not found: $source_dir" "$EXIT_GENERAL_ERROR"
    fi
    
    echo "Installing templates from: $source_dir"
    
    # Find and install .art files
    while IFS= read -r -d '' template_file; do
        local template_name=$(basename "$template_file")
        local dest_file="$ART_DIR/$template_name"
        
        if [[ -f "$dest_file" ]] && [[ "$force_update" != "true" ]]; then
            echo "  Skipping existing template: $template_name (use --force to overwrite)"
            continue
        fi
        
        if cp "$template_file" "$dest_file"; then
            chmod 644 "$dest_file"
            if [[ -f "$dest_file" ]] && [[ "$force_update" == "true" ]]; then
                echo "  Updated: $template_name"
                ((updated_count++))
            else
                echo "  Installed: $template_name"
                ((installed_count++))
            fi
            log_message "INFO" "Template installed: $template_name"
        else
            echo "  Failed to install: $template_name" >&2
            log_message "ERROR" "Failed to install template: $template_name"
        fi
    done < <(find "$source_dir" -name "*.art" -type f -print0)
    
    echo
    echo "Update complete:"
    echo "  New templates installed: $installed_count"
    echo "  Templates updated: $updated_count"
    
    log_message "INFO" "Template update completed: $installed_count new, $updated_count updated"
}

# List available templates in repository
list_remote_templates() {
    local repo_url="$1"
    
    echo "Available templates in repository: $repo_url"
    echo "(Use 'welcome-art update' to download them)"
    echo
    
    # This is a simplified implementation
    # In a real scenario, you might want to fetch and parse the repository
    echo "Note: Use 'welcome-art update' to see available templates after download."
}

# Show help
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Download and update art templates from repository.

OPTIONS:
    --force         Overwrite existing templates
    --list-remote   List available templates in repository
    --repo URL      Use custom repository URL
    --help          Show this help

EXAMPLES:
    $SCRIPT_NAME                    # Update templates from default repository
    $SCRIPT_NAME --force            # Force update all templates
    $SCRIPT_NAME --list-remote      # List available remote templates
    $SCRIPT_NAME --repo URL         # Update from custom repository

FILES:
    $ART_DIR/                       # Local templates directory
    $SYSTEM_CONFIG_FILE             # Configuration file

EOF
}

# Main function
main() {
    local force_update="false"
    local list_remote="false"
    local custom_repo=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                force_update="true"
                shift
                ;;
            --list-remote)
                list_remote="true"
                shift
                ;;
            --repo)
                custom_repo="$2"
                shift 2
                ;;
            --help)
                show_help
                exit "$EXIT_SUCCESS"
                ;;
            --*)
                error_exit "Unknown option: $1" "$EXIT_GENERAL_ERROR"
                ;;
            *)
                error_exit "Unknown argument: $1" "$EXIT_GENERAL_ERROR"
                ;;
        esac
    done
    
    # Get repository URL
    local repo_url
    if [[ -n "$custom_repo" ]]; then
        repo_url="$custom_repo"
    else
        repo_url=$(get_repo_url)
    fi
    
    # Execute requested action
    if [[ "$list_remote" == "true" ]]; then
        list_remote_templates "$repo_url"
    else
        check_permissions
        download_templates "$repo_url" "$force_update"
    fi
}

# Run main function with all arguments
main "$@"