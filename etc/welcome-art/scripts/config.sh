#!/bin/bash

# Welcome-Art Config Subcommand
# Edit system or user configuration files

set -euo pipefail

# Configuration
SCRIPT_NAME="welcome-art config"
SYSTEM_CONFIG_DIR="/etc/welcome-art"
SYSTEM_CONFIG_FILE="$SYSTEM_CONFIG_DIR/config"
USER_CONFIG_FILE="$HOME/.welcome-artrc"
USER_CONFIG_TEMPLATE="$SYSTEM_CONFIG_DIR/welcome-artrc.template"
LOG_FILE="/var/log/welcome-art.log"

# Exit codes
EXIT_SUCCESS=0
EXIT_GENERAL_ERROR=1
EXIT_CONFIG_ERROR=3
EXIT_PERMISSION_DENIED=5

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -w "$(dirname "$LOG_FILE")" ]] 2>/dev/null; then
        echo "[$timestamp] [$level] [CONFIG] $message" >> "$LOG_FILE" 2>/dev/null || true
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

# Get preferred editor
get_editor() {
    local editor=""
    
    # Check environment variables
    if [[ -n "${VISUAL:-}" ]]; then
        editor="$VISUAL"
    elif [[ -n "${EDITOR:-}" ]]; then
        editor="$EDITOR"
    else
        # Try common editors
        for cmd in nano vim vi emacs; do
            if command -v "$cmd" >/dev/null 2>&1; then
                editor="$cmd"
                break
            fi
        done
    fi
    
    if [[ -z "$editor" ]]; then
        error_exit "No suitable editor found. Set EDITOR or VISUAL environment variable." "$EXIT_GENERAL_ERROR"
    fi
    
    echo "$editor"
}

# Edit system configuration
edit_system_config() {
    local editor="$1"
    
    if [[ ! -w "$SYSTEM_CONFIG_FILE" ]]; then
        error_exit "No write permission to $SYSTEM_CONFIG_FILE. Run as root or with sudo." "$EXIT_PERMISSION_DENIED"
    fi
    
    echo "Editing system configuration: $SYSTEM_CONFIG_FILE"
    log_message "INFO" "Editing system configuration"
    
    # Create backup
    local backup_file="${SYSTEM_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    if cp "$SYSTEM_CONFIG_FILE" "$backup_file"; then
        echo "Backup created: $backup_file"
    fi
    
    # Edit configuration
    if "$editor" "$SYSTEM_CONFIG_FILE"; then
        echo "System configuration updated successfully."
        log_message "INFO" "System configuration updated"
        
        # Validate configuration
        if validate_config "$SYSTEM_CONFIG_FILE"; then
            echo "Configuration validation passed."
        else
            echo "Warning: Configuration validation failed. Please check syntax." >&2
            log_message "WARN" "Configuration validation failed"
        fi
    else
        error_exit "Failed to edit configuration file" "$EXIT_CONFIG_ERROR"
    fi
}

# Edit user configuration
edit_user_config() {
    local editor="$1"
    
    # Create user config from template if it doesn't exist
    if [[ ! -f "$USER_CONFIG_FILE" ]]; then
        echo "Creating user configuration file: $USER_CONFIG_FILE"
        
        if [[ -f "$USER_CONFIG_TEMPLATE" ]]; then
            if cp "$USER_CONFIG_TEMPLATE" "$USER_CONFIG_FILE"; then
                echo "User configuration created from template."
                log_message "INFO" "User configuration created from template"
            else
                error_exit "Failed to create user configuration from template" "$EXIT_CONFIG_ERROR"
            fi
        else
            # Create minimal user config
            cat > "$USER_CONFIG_FILE" << 'EOF'
# Welcome-Art User Configuration
# Personal settings that override system configuration

[display]
# template=modern
# welcome_text="Welcome back, {{USER}}!"
# color_enabled=true

[personal]
# show_system_info=true
# show_last_login=false
# custom_message="Have a great day!"
EOF
            echo "Minimal user configuration created."
            log_message "INFO" "Minimal user configuration created"
        fi
    fi
    
    echo "Editing user configuration: $USER_CONFIG_FILE"
    log_message "INFO" "Editing user configuration"
    
    # Create backup
    local backup_file="${USER_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    if cp "$USER_CONFIG_FILE" "$backup_file"; then
        echo "Backup created: $backup_file"
    fi
    
    # Edit configuration
    if "$editor" "$USER_CONFIG_FILE"; then
        echo "User configuration updated successfully."
        log_message "INFO" "User configuration updated"
        
        # Validate configuration
        if validate_config "$USER_CONFIG_FILE"; then
            echo "Configuration validation passed."
        else
            echo "Warning: Configuration validation failed. Please check syntax." >&2
            log_message "WARN" "User configuration validation failed"
        fi
    else
        error_exit "Failed to edit user configuration file" "$EXIT_CONFIG_ERROR"
    fi
}

# Validate configuration file syntax
validate_config() {
    local config_file="$1"
    local valid=true
    local line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Check section headers
        if [[ "$line" =~ ^[[:space:]]*\[.*\][[:space:]]*$ ]]; then
            continue
        fi
        
        # Check key=value pairs
        if [[ "$line" =~ ^[[:space:]]*[^=]+=[^=]*$ ]]; then
            continue
        fi
        
        # Invalid line found
        echo "Invalid syntax at line $line_num: $line" >&2
        valid=false
    done < "$config_file"
    
    if [[ "$valid" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Show current configuration
show_config() {
    local config_type="$1"
    
    case "$config_type" in
        "system")
            echo "System Configuration ($SYSTEM_CONFIG_FILE):"
            echo "================================================"
            if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
                cat "$SYSTEM_CONFIG_FILE"
            else
                echo "System configuration file not found."
            fi
            ;;
        "user")
            echo "User Configuration ($USER_CONFIG_FILE):"
            echo "==========================================="
            if [[ -f "$USER_CONFIG_FILE" ]]; then
                cat "$USER_CONFIG_FILE"
            else
                echo "User configuration file not found."
                echo "Run 'welcome-art config --user' to create one."
            fi
            ;;
        "both")
            show_config "system"
            echo
            show_config "user"
            ;;
    esac
}

# Reset configuration to defaults
reset_config() {
    local config_type="$1"
    local force="${2:-false}"
    
    case "$config_type" in
        "user")
            if [[ -f "$USER_CONFIG_FILE" ]] && [[ "$force" != "true" ]]; then
                echo "User configuration exists. Use --force to overwrite."
                return 1
            fi
            
            if [[ -f "$USER_CONFIG_TEMPLATE" ]]; then
                cp "$USER_CONFIG_TEMPLATE" "$USER_CONFIG_FILE"
                echo "User configuration reset to template."
                log_message "INFO" "User configuration reset to template"
            else
                error_exit "Template file not found: $USER_CONFIG_TEMPLATE" "$EXIT_CONFIG_ERROR"
            fi
            ;;
        "system")
            error_exit "Cannot reset system configuration. Edit manually or reinstall package." "$EXIT_PERMISSION_DENIED"
            ;;
    esac
}

# Show help
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Edit welcome-art configuration files.

OPTIONS:
    --user          Edit user configuration (~/.welcome-artrc)
    --system        Edit system configuration (/etc/welcome-art/config)
    --show [TYPE]   Show current configuration (system|user|both)
    --reset TYPE    Reset configuration to defaults (user only)
    --force         Force reset without confirmation
    --validate FILE Validate configuration file syntax
    --help          Show this help

EXAMPLES:
    $SCRIPT_NAME --user             # Edit user configuration
    $SCRIPT_NAME --system           # Edit system configuration (requires root)
    $SCRIPT_NAME --show both        # Show both configurations
    $SCRIPT_NAME --reset user       # Reset user config to template
    $SCRIPT_NAME --validate ~/.welcome-artrc  # Validate config file

FILES:
    $SYSTEM_CONFIG_FILE             # System configuration
    $USER_CONFIG_FILE               # User configuration
    $USER_CONFIG_TEMPLATE           # User configuration template

NOTE:
    System configuration requires root privileges.
    User configuration overrides system settings.

EOF
}

# Main function
main() {
    local edit_user="false"
    local edit_system="false"
    local show_type=""
    local reset_type=""
    local validate_file=""
    local force="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user)
                edit_user="true"
                shift
                ;;
            --system)
                edit_system="true"
                shift
                ;;
            --show)
                show_type="${2:-both}"
                shift 2
                ;;
            --reset)
                reset_type="$2"
                shift 2
                ;;
            --validate)
                validate_file="$2"
                shift 2
                ;;
            --force)
                force="true"
                shift
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
    
    # Execute requested action
    if [[ -n "$validate_file" ]]; then
        if validate_config "$validate_file"; then
            echo "Configuration file is valid: $validate_file"
        else
            error_exit "Configuration file has syntax errors: $validate_file" "$EXIT_CONFIG_ERROR"
        fi
    elif [[ -n "$show_type" ]]; then
        show_config "$show_type"
    elif [[ -n "$reset_type" ]]; then
        reset_config "$reset_type" "$force"
    elif [[ "$edit_system" == "true" ]]; then
        local editor
        editor=$(get_editor)
        edit_system_config "$editor"
    elif [[ "$edit_user" == "true" ]]; then
        local editor
        editor=$(get_editor)
        edit_user_config "$editor"
    else
        # Default to user configuration
        local editor
        editor=$(get_editor)
        edit_user_config "$editor"
    fi
}

# Run main function with all arguments
main "$@"