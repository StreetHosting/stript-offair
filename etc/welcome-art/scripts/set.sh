#!/bin/bash

# Welcome-Art Set Subcommand
# Activate and manage art templates

set -euo pipefail

# Configuration
SCRIPT_NAME="welcome-art set"
SYSTEM_CONFIG_DIR="/etc/welcome-art"
SYSTEM_CONFIG_FILE="$SYSTEM_CONFIG_DIR/config"
USER_CONFIG_FILE="$HOME/.welcome-artrc"
ART_TEMPLATES_DIR="$SYSTEM_CONFIG_DIR/art"
USER_TEMPLATES_DIR="$HOME/.welcome-art/art"
LOG_FILE="/var/log/welcome-art.log"

# Exit codes
EXIT_SUCCESS=0
EXIT_GENERAL_ERROR=1
EXIT_CONFIG_ERROR=3
EXIT_TEMPLATE_ERROR=4
EXIT_PERMISSION_DENIED=5

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -w "$(dirname "$LOG_FILE")" ]] 2>/dev/null; then
        echo "[$timestamp] [$level] [SET] $message" >> "$LOG_FILE" 2>/dev/null || true
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

# Find template file
find_template() {
    local template_name="$1"
    
    # Check user templates first (they override system templates)
    if [[ -f "$USER_TEMPLATES_DIR/$template_name.art" ]]; then
        echo "$USER_TEMPLATES_DIR/$template_name.art"
        return 0
    fi
    
    # Check system templates
    if [[ -f "$ART_TEMPLATES_DIR/$template_name.art" ]]; then
        echo "$ART_TEMPLATES_DIR/$template_name.art"
        return 0
    fi
    
    return 1
}

# Validate template file
validate_template() {
    local template_file="$1"
    
    if [[ ! -f "$template_file" ]]; then
        return 1
    fi
    
    # Check if template has required metadata
    local has_font has_alignment
    has_font=$(grep -q "^# Font:" "$template_file" && echo "true" || echo "false")
    has_alignment=$(grep -q "^# Alignment:" "$template_file" && echo "true" || echo "false")
    
    if [[ "$has_font" == "false" ]] || [[ "$has_alignment" == "false" ]]; then
        echo "Warning: Template missing required metadata (Font or Alignment)" >&2
        log_message "WARN" "Template validation warning: missing metadata in $template_file"
    fi
    
    return 0
}

# Update configuration file
update_config() {
    local config_file="$1"
    local key="$2"
    local value="$3"
    local section="${4:-display}"
    
    # Create config file if it doesn't exist
    if [[ ! -f "$config_file" ]]; then
        mkdir -p "$(dirname "$config_file")"
        cat > "$config_file" << EOF
# Welcome-Art Configuration

[$section]
$key=$value
EOF
        return 0
    fi
    
    # Create backup
    local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$config_file" "$backup_file" 2>/dev/null || true
    
    # Use awk to update the configuration
    awk -v section="$section" -v key="$key" -v value="$value" '
    BEGIN {
        in_section = 0
        key_found = 0
        section_found = 0
    }
    
    # Track current section
    /^\[.*\]$/ {
        if ($0 == "[" section "]") {
            in_section = 1
            section_found = 1
        } else {
            if (in_section && !key_found) {
                print key "=" value
                key_found = 1
            }
            in_section = 0
        }
        print
        next
    }
    
    # Update key in current section
    in_section && /^[^#]/ && /=/ {
        split($0, parts, "=")
        if (parts[1] == key) {
            print key "=" value
            key_found = 1
            next
        }
    }
    
    # Print all other lines
    { print }
    
    END {
        # Add section and key if not found
        if (!section_found) {
            print ""
            print "[" section "]"
            print key "=" value
        } else if (!key_found) {
            print key "=" value
        }
    }
    ' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
}

# Set template for user
set_user_template() {
    local template_name="$1"
    local template_file
    
    # Find template
    if ! template_file=$(find_template "$template_name"); then
        error_exit "Template not found: $template_name" "$EXIT_TEMPLATE_ERROR"
    fi
    
    # Validate template
    if ! validate_template "$template_file"; then
        error_exit "Invalid template: $template_name" "$EXIT_TEMPLATE_ERROR"
    fi
    
    # Update user configuration
    echo "Setting template '$template_name' for user..."
    
    # Create user config directory if needed
    mkdir -p "$(dirname "$USER_CONFIG_FILE")"
    
    # Update configuration
    update_config "$USER_CONFIG_FILE" "template" "$template_name" "display"
    
    echo "User template set to: $template_name"
    echo "Configuration updated: $USER_CONFIG_FILE"
    log_message "INFO" "User template set to: $template_name"
    
    # Show template info
    local title description
    title=$(grep "^# Title:" "$template_file" 2>/dev/null | sed 's/^# Title:[[:space:]]*//' || echo "Unknown")
    description=$(grep "^# Description:" "$template_file" 2>/dev/null | sed 's/^# Description:[[:space:]]*//' || echo "No description")
    
    echo "Template: $title"
    echo "Description: $description"
}

# Set template system-wide
set_system_template() {
    local template_name="$1"
    local template_file
    
    # Check permissions
    if [[ ! -w "$SYSTEM_CONFIG_FILE" ]]; then
        error_exit "No write permission to $SYSTEM_CONFIG_FILE. Run as root or with sudo." "$EXIT_PERMISSION_DENIED"
    fi
    
    # Find template
    if ! template_file=$(find_template "$template_name"); then
        error_exit "Template not found: $template_name" "$EXIT_TEMPLATE_ERROR"
    fi
    
    # Validate template
    if ! validate_template "$template_file"; then
        error_exit "Invalid template: $template_name" "$EXIT_TEMPLATE_ERROR"
    fi
    
    # Update system configuration
    echo "Setting template '$template_name' system-wide..."
    
    # Update configuration
    update_config "$SYSTEM_CONFIG_FILE" "template" "$template_name" "display"
    
    echo "System template set to: $template_name"
    echo "Configuration updated: $SYSTEM_CONFIG_FILE"
    log_message "INFO" "System template set to: $template_name"
    
    # Show template info
    local title description
    title=$(grep "^# Title:" "$template_file" 2>/dev/null | sed 's/^# Title:[[:space:]]*//' || echo "Unknown")
    description=$(grep "^# Description:" "$template_file" 2>/dev/null | sed 's/^# Description:[[:space:]]*//' || echo "No description")
    
    echo "Template: $title"
    echo "Description: $description"
}

# Set welcome text
set_welcome_text() {
    local welcome_text="$1"
    local scope="$2"
    
    case "$scope" in
        "user")
            echo "Setting welcome text for user..."
            mkdir -p "$(dirname "$USER_CONFIG_FILE")"
            update_config "$USER_CONFIG_FILE" "welcome_text" "$welcome_text" "display"
            echo "User welcome text set to: $welcome_text"
            log_message "INFO" "User welcome text set: $welcome_text"
            ;;
        "system")
            if [[ ! -w "$SYSTEM_CONFIG_FILE" ]]; then
                error_exit "No write permission to $SYSTEM_CONFIG_FILE. Run as root or with sudo." "$EXIT_PERMISSION_DENIED"
            fi
            echo "Setting welcome text system-wide..."
            update_config "$SYSTEM_CONFIG_FILE" "welcome_text" "$welcome_text" "display"
            echo "System welcome text set to: $welcome_text"
            log_message "INFO" "System welcome text set: $welcome_text"
            ;;
    esac
}

# Set color option
set_color_option() {
    local color_enabled="$1"
    local scope="$2"
    
    case "$scope" in
        "user")
            echo "Setting color option for user..."
            mkdir -p "$(dirname "$USER_CONFIG_FILE")"
            update_config "$USER_CONFIG_FILE" "color_enabled" "$color_enabled" "display"
            echo "User color option set to: $color_enabled"
            log_message "INFO" "User color option set: $color_enabled"
            ;;
        "system")
            if [[ ! -w "$SYSTEM_CONFIG_FILE" ]]; then
                error_exit "No write permission to $SYSTEM_CONFIG_FILE. Run as root or with sudo." "$EXIT_PERMISSION_DENIED"
            fi
            echo "Setting color option system-wide..."
            update_config "$SYSTEM_CONFIG_FILE" "color_enabled" "$color_enabled" "display"
            echo "System color option set to: $color_enabled"
            log_message "INFO" "System color option set: $color_enabled"
            ;;
    esac
}

# Show current settings
show_current_settings() {
    echo "Current Welcome-Art Settings:"
    echo "============================="
    
    # Show system settings
    echo "System Configuration ($SYSTEM_CONFIG_FILE):"
    if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
        local sys_template sys_welcome sys_color
        sys_template=$(grep "^template=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 || echo "default")
        sys_welcome=$(grep "^welcome_text=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2- || echo "Welcome to {{HOSTNAME}}!")
        sys_color=$(grep "^color_enabled=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 || echo "true")
        
        echo "  Template: $sys_template"
        echo "  Welcome Text: $sys_welcome"
        echo "  Color Enabled: $sys_color"
    else
        echo "  (No system configuration found)"
    fi
    
    echo
    
    # Show user settings
    echo "User Configuration ($USER_CONFIG_FILE):"
    if [[ -f "$USER_CONFIG_FILE" ]]; then
        local user_template user_welcome user_color
        user_template=$(grep "^template=" "$USER_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 || echo "(not set)")
        user_welcome=$(grep "^welcome_text=" "$USER_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2- || echo "(not set)")
        user_color=$(grep "^color_enabled=" "$USER_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 || echo "(not set)")
        
        echo "  Template: $user_template"
        echo "  Welcome Text: $user_welcome"
        echo "  Color Enabled: $user_color"
    else
        echo "  (No user configuration found)"
    fi
    
    echo
    echo "Note: User settings override system settings."
}

# Test current configuration
test_configuration() {
    echo "Testing current configuration..."
    echo "================================"
    
    # Run welcome-art with test flag
    if command -v welcome-art >/dev/null 2>&1; then
        echo "Running welcome-art --test..."
        echo
        welcome-art --test || echo "Test failed with exit code: $?"
    else
        echo "welcome-art command not found in PATH"
        echo "Make sure the package is properly installed."
    fi
}

# Show help
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] COMMAND [ARGS]

Activate and manage art templates.

COMMANDS:
    template NAME       Set active template
    welcome-text TEXT   Set welcome text
    color on|off        Enable/disable colors
    show                Show current settings
    test                Test current configuration

OPTIONS:
    --user              Apply to user configuration (default)
    --system            Apply to system configuration (requires root)
    --help              Show this help

EXAMPLES:
    $SCRIPT_NAME template modern        # Set user template to 'modern'
    $SCRIPT_NAME --system template default  # Set system template to 'default'
    $SCRIPT_NAME welcome-text "Hello {{USER}}!"  # Set user welcome text
    $SCRIPT_NAME color off              # Disable colors for user
    $SCRIPT_NAME show                   # Show current settings
    $SCRIPT_NAME test                   # Test configuration

TEMPLATE VARIABLES:
    {{USER}}            Current username
    {{HOSTNAME}}        System hostname
    {{DATE}}            Current date
    {{TIME}}            Current time
    {{UPTIME}}          System uptime
    {{LOAD}}            System load average

FILES:
    $SYSTEM_CONFIG_FILE             # System configuration
    $USER_CONFIG_FILE               # User configuration
    $ART_TEMPLATES_DIR              # System templates
    $USER_TEMPLATES_DIR             # User templates

NOTE:
    User configuration overrides system settings.
    System configuration requires root privileges.
    Use 'welcome-art list' to see available templates.

EOF
}

# Main function
main() {
    local scope="user"
    local command=""
    local args=()
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user)
                scope="user"
                shift
                ;;
            --system)
                scope="system"
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
                if [[ -z "$command" ]]; then
                    command="$1"
                else
                    args+=("$1")
                fi
                shift
                ;;
        esac
    done
    
    # Execute command
    case "$command" in
        "template")
            if [[ ${#args[@]} -eq 0 ]]; then
                error_exit "Template name required" "$EXIT_GENERAL_ERROR"
            fi
            
            local template_name="${args[0]}"
            
            if [[ "$scope" == "system" ]]; then
                set_system_template "$template_name"
            else
                set_user_template "$template_name"
            fi
            ;;
        "welcome-text")
            if [[ ${#args[@]} -eq 0 ]]; then
                error_exit "Welcome text required" "$EXIT_GENERAL_ERROR"
            fi
            
            local welcome_text="${args[*]}"
            set_welcome_text "$welcome_text" "$scope"
            ;;
        "color")
            if [[ ${#args[@]} -eq 0 ]]; then
                error_exit "Color option required (on|off)" "$EXIT_GENERAL_ERROR"
            fi
            
            local color_option="${args[0]}"
            case "$color_option" in
                "on"|"true"|"yes"|"1")
                    set_color_option "true" "$scope"
                    ;;
                "off"|"false"|"no"|"0")
                    set_color_option "false" "$scope"
                    ;;
                *)
                    error_exit "Invalid color option: $color_option. Use 'on' or 'off'." "$EXIT_GENERAL_ERROR"
                    ;;
            esac
            ;;
        "show")
            show_current_settings
            ;;
        "test")
            test_configuration
            ;;
        "")
            error_exit "Command required. Use --help for usage information." "$EXIT_GENERAL_ERROR"
            ;;
        *)
            error_exit "Unknown command: $command" "$EXIT_GENERAL_ERROR"
            ;;
    esac
}

# Run main function with all arguments
main "$@"