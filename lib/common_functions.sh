#!/bin/bash
# Laravel Development Environment - Common Functions Library
# Version: 2.0
# Copyright: Laravel Development Environment Project
# 
# This library provides professional logging, error handling, and utility functions
# for all Laravel environment management scripts.

set -euo pipefail

# Configuration
readonly LOG_DIR="/var/log/laravel-env"
readonly LOG_FILE="${LOG_DIR}/operations.log"
readonly AUDIT_LOG="${LOG_DIR}/audit.log"
readonly ERROR_LOG="${LOG_DIR}/error.log"
readonly TIMESTAMP_FORMAT='+%Y-%m-%d %H:%M:%S'

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_DEPENDENCY_ERROR=2
readonly EXIT_PERMISSION_ERROR=3
readonly EXIT_VALIDATION_ERROR=4
readonly EXIT_NETWORK_ERROR=5
readonly EXIT_RESOURCE_ERROR=6

# Log levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_CRITICAL=4

# Current log level (default: INFO)
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Initialize logging system
init_logging() {
    # Create log directory if it doesn't exist
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            echo "[ERROR] Failed to create log directory: $LOG_DIR" >&2
            return 1
        }
    fi
    
    # Set appropriate permissions
    chmod 755 "$LOG_DIR" 2>/dev/null || true
    
    # Initialize log files
    for log_file in "$LOG_FILE" "$AUDIT_LOG" "$ERROR_LOG"; do
        touch "$log_file" 2>/dev/null || true
        chmod 644 "$log_file" 2>/dev/null || true
    done
    
    # Log initialization
    log_info "Logging system initialized"
}

# Professional logging functions
log_message() {
    local level=$1
    local level_name=$2
    local message=$3
    local timestamp=$(date "$TIMESTAMP_FORMAT")
    local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}"
    
    # Check if message should be logged based on level
    if [[ $level -ge $LOG_LEVEL ]]; then
        # Log to file
        echo "[${timestamp}] [${level_name}] [${caller}] ${message}" >> "$LOG_FILE"
        
        # Also log errors to error log
        if [[ $level -ge $LOG_LEVEL_ERROR ]]; then
            echo "[${timestamp}] [${level_name}] [${caller}] ${message}" >> "$ERROR_LOG"
        fi
        
        # Send to syslog for enterprise integration
        if command -v logger &> /dev/null; then
            logger -t "laravel-env" -p "local0.${level_name,,}" "${message}"
        fi
    fi
}

log_debug() {
    log_message $LOG_LEVEL_DEBUG "DEBUG" "$1"
}

log_info() {
    log_message $LOG_LEVEL_INFO "INFO" "$1"
}

log_warn() {
    log_message $LOG_LEVEL_WARN "WARNING" "$1"
}

log_error() {
    log_message $LOG_LEVEL_ERROR "ERROR" "$1"
}

log_critical() {
    log_message $LOG_LEVEL_CRITICAL "CRITICAL" "$1"
}

# Audit logging for compliance
log_audit() {
    local action=$1
    local resource=$2
    local result=$3
    local details=${4:-""}
    local timestamp=$(date "$TIMESTAMP_FORMAT")
    local user="${SUDO_USER:-${USER:-unknown}}"
    
    local audit_entry=$(cat <<EOF
{
  "timestamp": "${timestamp}",
  "user": "${user}",
  "action": "${action}",
  "resource": "${resource}",
  "result": "${result}",
  "details": "${details}",
  "pid": $$,
  "script": "${0##*/}"
}
EOF
)
    
    echo "$audit_entry" >> "$AUDIT_LOG"
}

# Professional status output (no emojis)
print_status() {
    local status=$1
    local message=$2
    local timestamp=$(date '+%H:%M:%S')
    
    case "$status" in
        "SUCCESS")
            echo -e "\033[32m[SUCCESS]\033[0m ${message}"
            ;;
        "ERROR")
            echo -e "\033[31m[ERROR]\033[0m ${message}" >&2
            ;;
        "WARNING")
            echo -e "\033[33m[WARNING]\033[0m ${message}"
            ;;
        "INFO")
            echo -e "\033[34m[INFO]\033[0m ${message}"
            ;;
        "PROGRESS")
            echo -e "\033[36m[PROGRESS]\033[0m ${message}"
            ;;
        *)
            echo "[${timestamp}] ${message}"
            ;;
    esac
}

# Enhanced error handling with recovery
handle_error() {
    local exit_code=$1
    local error_message=$2
    local recovery_function=${3:-""}
    
    log_error "Error occurred: ${error_message} (Exit code: ${exit_code})"
    print_status "ERROR" "${error_message}"
    
    # Attempt recovery if function provided
    if [[ -n "$recovery_function" ]] && declare -f "$recovery_function" > /dev/null; then
        log_info "Attempting recovery using: ${recovery_function}"
        if $recovery_function; then
            log_info "Recovery successful"
            return 0
        else
            log_error "Recovery failed"
        fi
    fi
    
    # Generate error report
    generate_error_report "$exit_code" "$error_message"
    
    exit "$exit_code"
}

# Retry mechanism with exponential backoff
retry_with_backoff() {
    local max_attempts=${RETRY_MAX_ATTEMPTS:-3}
    local timeout=${RETRY_INITIAL_TIMEOUT:-1}
    local attempt=0
    local exit_code=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        log_debug "Executing command (attempt $((attempt + 1))/$max_attempts): $*"
        
        if "$@"; then
            if [[ $attempt -gt 0 ]]; then
                log_info "Command succeeded after $((attempt + 1)) attempts"
            fi
            return 0
        fi
        
        exit_code=$?
        attempt=$((attempt + 1))
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_warn "Command failed (attempt $attempt/$max_attempts), retrying in ${timeout}s..."
            sleep "$timeout"
            timeout=$((timeout * 2))
        fi
    done
    
    log_error "Command failed after ${max_attempts} attempts: $*"
    return $exit_code
}

# Resource checking
check_system_resources() {
    local min_disk_space_gb=${MIN_DISK_SPACE_GB:-5}
    local min_memory_mb=${MIN_MEMORY_MB:-1024}
    
    log_info "Checking system resources..."
    
    # Check disk space
    local available_space_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_space_gb -lt $min_disk_space_gb ]]; then
        log_error "Insufficient disk space: ${available_space_gb}GB available, ${min_disk_space_gb}GB required"
        return $EXIT_RESOURCE_ERROR
    fi
    
    # Check memory
    local available_memory_mb=$(free -m | awk 'NR==2 {print $7}')
    if [[ $available_memory_mb -lt $min_memory_mb ]]; then
        log_error "Insufficient memory: ${available_memory_mb}MB available, ${min_memory_mb}MB required"
        return $EXIT_RESOURCE_ERROR
    fi
    
    log_info "Resource check passed: ${available_space_gb}GB disk, ${available_memory_mb}MB memory available"
    return 0
}

# Configuration validation
validate_configuration() {
    local config_file=$1
    
    log_info "Validating configuration: ${config_file}"
    
    # Check if file exists
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: ${config_file}"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Validate YAML/JSON syntax (if applicable)
    if [[ "$config_file" =~ \.(yml|yaml)$ ]]; then
        if command -v yq &> /dev/null; then
            if ! yq eval '.' "$config_file" > /dev/null 2>&1; then
                log_error "Invalid YAML syntax in: ${config_file}"
                return $EXIT_VALIDATION_ERROR
            fi
        fi
    elif [[ "$config_file" =~ \.json$ ]]; then
        if command -v jq &> /dev/null; then
            if ! jq '.' "$config_file" > /dev/null 2>&1; then
                log_error "Invalid JSON syntax in: ${config_file}"
                return $EXIT_VALIDATION_ERROR
            fi
        fi
    fi
    
    log_info "Configuration validation passed"
    return 0
}

# Generate error report
generate_error_report() {
    local exit_code=$1
    local error_message=$2
    local report_file="${LOG_DIR}/error_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" <<EOF
Laravel Development Environment - Error Report
Generated: $(date "$TIMESTAMP_FORMAT")

Error Summary:
--------------
Exit Code: ${exit_code}
Error Message: ${error_message}
Script: ${0}
User: ${USER}
Working Directory: $(pwd)

System Information:
------------------
Hostname: $(hostname)
OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
Kernel: $(uname -r)
Architecture: $(uname -m)

Recent Log Entries:
------------------
$(tail -n 20 "$ERROR_LOG" 2>/dev/null || echo "No error log available")

Environment Variables:
---------------------
$(env | grep -E '^(LARAVEL_|PHP_|NGINX_|MYSQL_|POSTGRES_)' | sort)

Recommendations:
---------------
1. Check the full error log: ${ERROR_LOG}
2. Verify system requirements are met
3. Ensure all dependencies are installed
4. Check file permissions
5. Review configuration files

For support, please include this error report.
EOF
    
    log_info "Error report generated: ${report_file}"
    print_status "INFO" "Error report saved to: ${report_file}"
}

# Professional progress indicator
show_progress() {
    local current=$1
    local total=$2
    local task=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r[PROGRESS] [%${filled}s%${empty}s] %3d%% - %s" \
        "$(printf '=%.0s' $(seq 1 $filled))" \
        "" \
        "$percent" \
        "$task"
    
    if [[ $current -eq $total ]]; then
        echo # New line when complete
    fi
}

# Dependency checking
check_dependencies() {
    local dependencies=("$@")
    local missing=()
    
    log_info "Checking dependencies..."
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
            log_warn "Missing dependency: ${dep}"
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        print_status "ERROR" "Missing required dependencies: ${missing[*]}"
        return $EXIT_DEPENDENCY_ERROR
    fi
    
    log_info "All dependencies satisfied"
    return 0
}

# Lock file management for preventing concurrent operations
acquire_lock() {
    local lock_name=$1
    local lock_file="${LOG_DIR}/.${lock_name}.lock"
    local timeout=${2:-30}
    local elapsed=0
    
    # Ensure log directory exists
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    
    while [[ -f "$lock_file" ]] && [[ $elapsed -lt $timeout ]]; do
        # Check if the process that created the lock is still running
        if [[ -f "$lock_file" ]]; then
            local lock_pid=$(cat "$lock_file" 2>/dev/null || echo "0")
            if ! kill -0 "$lock_pid" 2>/dev/null; then
                # Process is dead, remove stale lock
                rm -f "$lock_file"
                log_info "Removed stale lock file for ${lock_name} (PID $lock_pid no longer exists)"
                break
            fi
        fi
        
        log_debug "Waiting for lock: ${lock_name}"
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    if [[ -f "$lock_file" ]]; then
        log_error "Failed to acquire lock: ${lock_name} (timeout after ${timeout}s)"
        return 1
    fi
    
    echo $$ > "$lock_file"
    log_debug "Lock acquired: ${lock_name} (PID: $$)"
    return 0
}

release_lock() {
    local lock_name=$1
    local lock_file="${LOG_DIR}/.${lock_name}.lock"
    
    if [[ -f "$lock_file" ]]; then
        rm -f "$lock_file"
        log_debug "Lock released: ${lock_name}"
    fi
}

# Cleanup function for exit trap
cleanup_on_exit() {
    local exit_code=$?
    
    # Release any locks
    for lock_file in "${LOG_DIR}"/.*.lock; do
        if [[ -f "$lock_file" ]]; then
            release_lock "$(basename "$lock_file" .lock)"
        fi
    done
    
    # Log script completion
    if [[ $exit_code -eq 0 ]]; then
        log_info "Script completed successfully"
    else
        log_error "Script failed with exit code: ${exit_code}"
    fi
    
    return $exit_code
}

# Check if running as root
check_root_privileges() {
    log_info "Checking root privileges"
    
    if [[ $EUID -ne 0 ]]; then
        print_status "ERROR" "This operation must be run with root privileges"
        print_status "INFO" "Please run with sudo"
        exit $EXIT_PERMISSION_ERROR
    fi
    
    log_info "Root privileges confirmed"
}

# Set up exit trap
trap cleanup_on_exit EXIT

# Initialize logging on source
init_logging 2>/dev/null || true