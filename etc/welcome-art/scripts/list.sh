#!/bin/bash

# Welcome-Art List Subcommand
# List available art templates with details

set -euo pipefail

# Configuration
SCRIPT_NAME="welcome-art list"
SYSTEM_CONFIG_DIR="/etc/welcome-art"
ART_TEMPLATES_DIR="$SYSTEM_CONFIG_DIR/art"
USER_TEMPLATES_DIR="$HOME/.welcome-art/art"
LOG_FILE="/var/log/welcome-art.log"

# Exit codes
EXIT_SUCCESS=0
EXIT_GENERAL_ERROR=1
EXIT_TEMPLATE_ERROR=4

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -w "$(dirname "$LOG_FILE")" ]] 2>/dev/null; then
        echo "[$timestamp] [$level] [LIST] $message" >> "$LOG_FILE" 2>/dev/null || true
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

# Parse template metadata
parse_template_metadata() {
    local template_file="$1"
    local key="$2"
    
    if [[ ! -f "$template_file" ]]; then
        echo "unknown"
        return 1
    fi
    
    # Extract metadata from template file
    local value
    value=$(grep "^# $key:" "$template_file" 2>/dev/null | sed "s/^# $key:[[:space:]]*//" | head -1)
    
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "unknown"
    fi
}

# Get template size
get_template_size() {
    local template_file="$1"
    
    if [[ -f "$template_file" ]]; then
        local size
        size=$(wc -c < "$template_file" 2>/dev/null || echo "0")
        
        if [[ "$size" -lt 1024 ]]; then
            echo "${size}B"
        elif [[ "$size" -lt 1048576 ]]; then
            echo "$((size / 1024))KB"
        else
            echo "$((size / 1048576))MB"
        fi
    else
        echo "0B"
    fi
}

# Get template modification time
get_template_mtime() {
    local template_file="$1"
    
    if [[ -f "$template_file" ]]; then
        if command -v stat >/dev/null 2>&1; then
            # Try GNU stat first
            stat -c "%Y" "$template_file" 2>/dev/null || \
            # Try BSD stat
            stat -f "%m" "$template_file" 2>/dev/null || \
            echo "0"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Format timestamp
format_timestamp() {
    local timestamp="$1"
    
    if [[ "$timestamp" == "0" ]]; then
        echo "unknown"
    else
        date -d "@$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null || \
        date -r "$timestamp" '+%Y-%m-%d %H:%M' 2>/dev/null || \
        echo "unknown"
    fi
}

# List templates in directory
list_templates_in_dir() {
    local templates_dir="$1"
    local source_type="$2"
    local format="$3"
    local show_details="$4"
    
    if [[ ! -d "$templates_dir" ]]; then
        return 0
    fi
    
    local templates
    templates=$(find "$templates_dir" -name "*.art" -type f 2>/dev/null | sort)
    
    if [[ -z "$templates" ]]; then
        return 0
    fi
    
    local count=0
    
    while IFS= read -r template_file; do
        [[ -z "$template_file" ]] && continue
        
        local template_name
        template_name=$(basename "$template_file" .art)
        
        case "$format" in
            "simple")
                echo "$template_name"
                ;;
            "detailed")
                local title description author version size mtime
                title=$(parse_template_metadata "$template_file" "Title")
                description=$(parse_template_metadata "$template_file" "Description")
                author=$(parse_template_metadata "$template_file" "Author")
                version=$(parse_template_metadata "$template_file" "Version")
                size=$(get_template_size "$template_file")
                mtime=$(get_template_mtime "$template_file")
                mtime=$(format_timestamp "$mtime")
                
                if [[ "$show_details" == "true" ]]; then
                    echo "Template: $template_name ($source_type)"
                    echo "  Title: $title"
                    echo "  Description: $description"
                    echo "  Author: $author"
                    echo "  Version: $version"
                    echo "  Size: $size"
                    echo "  Modified: $mtime"
                    echo "  Path: $template_file"
                    echo
                else
                    printf "%-20s %-10s %-40s %-15s %s\n" \
                        "$template_name" "$source_type" "$title" "$size" "$mtime"
                fi
                ;;
            "json")
                local title description author version size mtime_ts
                title=$(parse_template_metadata "$template_file" "Title")
                description=$(parse_template_metadata "$template_file" "Description")
                author=$(parse_template_metadata "$template_file" "Author")
                version=$(parse_template_metadata "$template_file" "Version")
                size=$(get_template_size "$template_file")
                mtime_ts=$(get_template_mtime "$template_file")
                
                if [[ "$count" -gt 0 ]]; then
                    echo ","
                fi
                
                cat << EOF
  {
    "name": "$template_name",
    "source": "$source_type",
    "title": "$title",
    "description": "$description",
    "author": "$author",
    "version": "$version",
    "size": "$size",
    "modified": $mtime_ts,
    "path": "$template_file"
  }
EOF
                ;;
        esac
        
        ((count++))
    done <<< "$templates"
    
    return "$count"
}

# Show template preview
show_template_preview() {
    local template_name="$1"
    local template_file=""
    
    # Find template file
    if [[ -f "$USER_TEMPLATES_DIR/$template_name.art" ]]; then
        template_file="$USER_TEMPLATES_DIR/$template_name.art"
    elif [[ -f "$ART_TEMPLATES_DIR/$template_name.art" ]]; then
        template_file="$ART_TEMPLATES_DIR/$template_name.art"
    else
        error_exit "Template not found: $template_name" "$EXIT_TEMPLATE_ERROR"
    fi
    
    echo "Template Preview: $template_name"
    echo "================================"
    echo "Path: $template_file"
    echo
    
    # Show metadata
    local title description author version
    title=$(parse_template_metadata "$template_file" "Title")
    description=$(parse_template_metadata "$template_file" "Description")
    author=$(parse_template_metadata "$template_file" "Author")
    version=$(parse_template_metadata "$template_file" "Version")
    
    echo "Title: $title"
    echo "Description: $description"
    echo "Author: $author"
    echo "Version: $version"
    echo
    
    # Show template content
    echo "Template Content:"
    echo "-----------------"
    cat "$template_file"
    echo
    
    # Show rendered preview if figlet is available
    if command -v figlet >/dev/null 2>&1; then
        echo "Rendered Preview (with sample text):"
        echo "------------------------------------"
        
        # Extract figlet settings
        local font alignment
        font=$(parse_template_metadata "$template_file" "Font")
        alignment=$(parse_template_metadata "$template_file" "Alignment")
        
        # Set figlet options
        local figlet_opts=""
        [[ "$font" != "unknown" ]] && figlet_opts="$figlet_opts -f $font"
        [[ "$alignment" == "center" ]] && figlet_opts="$figlet_opts -c"
        [[ "$alignment" == "right" ]] && figlet_opts="$figlet_opts -r"
        
        # Render sample text
        echo "Welcome" | figlet $figlet_opts 2>/dev/null || echo "(Preview not available)"
        echo
    fi
}

# Show help
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] [TEMPLATE]

List available art templates.

OPTIONS:
    --system        List only system templates
    --user          List only user templates
    --format FORMAT Output format (simple|detailed|json)
    --details       Show detailed information
    --preview NAME  Show template preview
    --count         Show only template count
    --help          Show this help

FORMATS:
    simple          Template names only (default)
    detailed        Detailed table format
    json            JSON format

EXAMPLES:
    $SCRIPT_NAME                    # List all templates (simple)
    $SCRIPT_NAME --format detailed  # List with details
    $SCRIPT_NAME --system           # List system templates only
    $SCRIPT_NAME --preview default  # Show template preview
    $SCRIPT_NAME --count            # Show template count
    $SCRIPT_NAME --format json      # JSON output

TEMPLATE LOCATIONS:
    System: $ART_TEMPLATES_DIR
    User:   $USER_TEMPLATES_DIR

NOTE:
    User templates override system templates with the same name.
    Use --preview to see template content and rendered output.

EOF
}

# Main function
main() {
    local list_system="true"
    local list_user="true"
    local format="simple"
    local show_details="false"
    local preview_template=""
    local show_count="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --system)
                list_system="true"
                list_user="false"
                shift
                ;;
            --user)
                list_system="false"
                list_user="true"
                shift
                ;;
            --format)
                format="$2"
                case "$format" in
                    "simple"|"detailed"|"json")
                        ;;
                    *)
                        error_exit "Invalid format: $format. Use simple, detailed, or json." "$EXIT_GENERAL_ERROR"
                        ;;
                esac
                shift 2
                ;;
            --details)
                show_details="true"
                format="detailed"
                shift
                ;;
            --preview)
                preview_template="$2"
                shift 2
                ;;
            --count)
                show_count="true"
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
                # Assume it's a template name for preview
                preview_template="$1"
                shift
                ;;
        esac
    done
    
    # Show template preview if requested
    if [[ -n "$preview_template" ]]; then
        show_template_preview "$preview_template"
        exit "$EXIT_SUCCESS"
    fi
    
    # Count templates
    local total_count=0
    
    # Initialize JSON output
    if [[ "$format" == "json" ]]; then
        echo "{"
        echo '  "templates": ['
    fi
    
    # Show header for detailed format
    if [[ "$format" == "detailed" ]] && [[ "$show_details" != "true" ]]; then
        printf "%-20s %-10s %-40s %-15s %s\n" \
            "NAME" "SOURCE" "TITLE" "SIZE" "MODIFIED"
        printf "%-20s %-10s %-40s %-15s %s\n" \
            "----" "------" "-----" "----" "--------"
    fi
    
    # List user templates first (they override system templates)
    if [[ "$list_user" == "true" ]]; then
        list_templates_in_dir "$USER_TEMPLATES_DIR" "user" "$format" "$show_details"
        local user_count=$?
        total_count=$((total_count + user_count))
    fi
    
    # List system templates
    if [[ "$list_system" == "true" ]]; then
        # Add comma separator for JSON if user templates were listed
        if [[ "$format" == "json" ]] && [[ "$list_user" == "true" ]] && [[ "$total_count" -gt 0 ]]; then
            echo ","
        fi
        
        list_templates_in_dir "$ART_TEMPLATES_DIR" "system" "$format" "$show_details"
        local system_count=$?
        total_count=$((total_count + system_count))
    fi
    
    # Close JSON output
    if [[ "$format" == "json" ]]; then
        echo
        echo "  ],"
        echo "  \"total_count\": $total_count"
        echo "}"
    fi
    
    # Show count if requested
    if [[ "$show_count" == "true" ]]; then
        echo
        echo "Total templates: $total_count"
        
        if [[ "$list_user" == "true" ]] && [[ "$list_system" == "true" ]]; then
            local user_count system_count
            user_count=$(find "$USER_TEMPLATES_DIR" -name "*.art" -type f 2>/dev/null | wc -l)
            system_count=$(find "$ART_TEMPLATES_DIR" -name "*.art" -type f 2>/dev/null | wc -l)
            echo "  User templates: $user_count"
            echo "  System templates: $system_count"
        fi
    fi
    
    # Log the action
    log_message "INFO" "Listed $total_count templates (format: $format)"
    
    if [[ "$total_count" -eq 0 ]]; then
        echo "No templates found."
        echo "Use 'welcome-art update' to download templates."
        exit "$EXIT_TEMPLATE_ERROR"
    fi
}

# Run main function with all arguments
main "$@"