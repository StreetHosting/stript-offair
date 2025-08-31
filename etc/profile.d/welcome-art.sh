#!/bin/bash

# Welcome-Art Auto-Execution Script
# Automatically runs welcome-art on SSH/VPS login
# Place this file in /etc/profile.d/ for system-wide execution

# Configuration
WELCOME_ART_BIN="/usr/local/bin/welcome-art"
SYSTEM_CONFIG_DIR="/etc/welcome-art"
SYSTEM_CONFIG_FILE="$SYSTEM_CONFIG_DIR/config"
USER_CONFIG_FILE="$HOME/.welcome-artrc"
LOG_FILE="/var/log/welcome-art.log"

# Only run for interactive shells
if [[ $- != *i* ]]; then
    return 0
fi

# Only run for SSH sessions or if explicitly enabled
if [[ -z "${SSH_CONNECTION:-}" ]] && [[ -z "${SSH_CLIENT:-}" ]] && [[ -z "${SSH_TTY:-}" ]]; then
    # Check if auto-execution is enabled for local sessions
    local_execution_enabled="false"
    
    # Check system configuration
    if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
        local_execution_enabled=$(grep "^auto_execute_local=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 || echo "false")
    fi
    
    # Check user configuration (overrides system)
    if [[ -f "$USER_CONFIG_FILE" ]]; then
        local user_setting
        user_setting=$(grep "^auto_execute_local=" "$USER_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 || echo "")
        if [[ -n "$user_setting" ]]; then
            local_execution_enabled="$user_setting"
        fi
    fi
    
    # Exit if local execution is disabled
    if [[ "$local_execution_enabled" != "true" ]]; then
        return 0
    fi
fi

# Check if welcome-art is disabled for this user
if [[ -f "$USER_CONFIG_FILE" ]]; then
    auto_execute=$(grep "^auto_execute=" "$USER_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 || echo "true")
    if [[ "$auto_execute" == "false" ]]; then
        return 0
    fi
fi

# Check if welcome-art is disabled system-wide
if [[ -f "$SYSTEM_CONFIG_FILE" ]]; then
    auto_execute=$(grep "^auto_execute=" "$SYSTEM_CONFIG_FILE" 2>/dev/null | cut -d'=' -f2 || echo "true")
    if [[ "$auto_execute" == "false" ]]; then
        return 0
    fi
fi

# Check if welcome-art binary exists and is executable
if [[ ! -x "$WELCOME_ART_BIN" ]]; then
    # Log the issue but don't show error to user
    if [[ -w "$(dirname "$LOG_FILE")" ]] 2>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [AUTO-EXEC] welcome-art binary not found or not executable: $WELCOME_ART_BIN" >> "$LOG_FILE" 2>/dev/null || true
    fi
    return 0
fi

# Check terminal capabilities
if [[ -z "${TERM:-}" ]] || [[ "$TERM" == "dumb" ]]; then
    return 0
fi

# Avoid running multiple times in the same session
if [[ -z "${WELCOME_ART_EXECUTED:-}" ]]; then
    # Mark as executed to prevent multiple runs in the same session
    export WELCOME_ART_EXECUTED="true"
    
    # Add a small delay to ensure terminal is ready
    sleep 0.1
    
    # Execute welcome-art with error handling
    if ! "$WELCOME_ART_BIN" --auto 2>/dev/null; then
        # Log execution failure but don't show error to user
        if [[ -w "$(dirname "$LOG_FILE")" ]] 2>/dev/null; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] [AUTO-EXEC] welcome-art execution failed with exit code: $?" >> "$LOG_FILE" 2>/dev/null || true
        fi
    fi
fi