#!/bin/bash

set -euo pipefail

# --- Logging Functions ---
log_info() {
    local -r timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\033[1;34m[$timestamp] INFO: $*\033[0m" >&2
}

log_error() {
    local -r timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\033[1;31m[$timestamp] ERROR: $*\033[0m" >&2
}

log_success() {
    local -r timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\033[1;32m[$timestamp] SUCCESS: $*\033[0m" >&2
}

log_warn() {
    local -r timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "\033[1;33m[$timestamp] WARN: $*\033[0m" >&2
}

log_debug() {
    if [[ ${DEBUG:-0} -eq 1 ]]; then
        local -r timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "\033[1;90m[$timestamp] DEBUG: $*\033[0m" >&2
    fi
}

# --- Error Handling ---
die() {
    log_error "$*"
    exit 1
}

# --- File System Utilities ---
ensure_directory() {
    local -r dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" || die "Failed to create directory: $dir"
        log_debug "Created directory: $dir"
    fi
}

validate_file() {
    local -r file="$1"
    local -r description="${2:-File}"
    
    [[ -f "$file" ]] || die "$description not found: $file"
}

validate_executable() {
    local -r file="$1"
    local -r description="${2:-Script}"
    
    validate_file "$file" "$description"
    [[ -x "$file" ]] || die "$description not executable: $file"
}

# --- Process Management ---
acquire_lock() {
    local -r lock_file="$1"
    local -r script_name="${2:-$(basename "$0")}"
    
    if [[ -f "$lock_file" ]]; then
        local pid
        pid=$(cat "$lock_file" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            die "Another instance of $script_name is already running (PID: $pid)"
        else
            log_info "Removing stale lock file: $lock_file"
            rm -f "$lock_file"
        fi
    fi
    
    echo $$ >"$lock_file"
    trap "rm -f '$lock_file'" EXIT INT TERM
}

# --- Dependency Validation ---
validate_dependencies() {
    local -ra required_deps=("$@")
    local missing_deps=()
    
    for dep in "${required_deps[@]}"; do
        command -v "$dep" >/dev/null 2>&1 || missing_deps+=("$dep")
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        die "Missing required dependencies: ${missing_deps[*]}"
    fi
    
    log_debug "All dependencies validated: ${required_deps[*]}"
}

# --- Notification Helper ---
send_notification() {
    local -r app_name="$1"
    local -r title="$2"
    local -r message="$3"
    local -r urgency="${4:-normal}"
    local -r icon="${5:-}"
    
    local notify_args=(
        --app-name="$app_name"
        --urgency="$urgency"
    )
    
    [[ -n "$icon" ]] && notify_args+=(--icon="$icon")
    
    notify-send "${notify_args[@]}" "$title" "$message"
}

# --- Functions ---
validate_git_repository() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        die "Not in a git repository!"
    fi
    
    if [[ ! -f .gitignore ]]; then
        die ".gitignore file not found!"
    fi
}

find_ignored_tracked_files() {
    git ls-files -ci --exclude-standard 2>/dev/null || echo ""
}

remove_files_from_tracking() {
    local -r files="$1"
    
    log_info "Removing files from git tracking..."
    
    echo "$files" | while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            log_info "Removing: $file"
            if ! git rm --cached "$file" 2>/dev/null; then
                log_warn "Could not remove: $file"
            fi
        fi
    done
}

show_staged_changes() {
    if git diff --cached --quiet; then
        log_success "No changes to commit."
    else
        log_info "Files removed from tracking. You can now commit these changes:"
        echo
        echo "  git commit -m \"Remove ignored files from tracking\""
        echo
        log_info "Staged changes:"
        git diff --cached --name-only | sed 's/^/  - /'
    fi
}

main() {
    log_info "🧹 Git Repository Cleanup Script"
    echo "================================="
    
    validate_git_repository
    
    log_info "Checking for files that should be ignored..."
    
    local ignored_files
    ignored_files=$(find_ignored_tracked_files)
    
    if [[ -z "$ignored_files" ]]; then
        log_success "No tracked files found that should be ignored!"
        exit 0
    fi
    
    echo
    log_warn "Found the following tracked files that should be ignored:"
    echo "$ignored_files" | sed 's/^/  - /'
    echo
    
    # Ask for confirmation
    read -p "Do you want to remove these files from git tracking? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled."
        exit 0
    fi
    
    remove_files_from_tracking "$ignored_files"
    show_staged_changes
    
    log_success "Cleanup completed!"
    
    # Show current status
    echo
    log_info "Current git status:"
    git status --short
    
    # Send notification
    send_notification "Git Cleanup" "Cleanup Complete" \
        "Removed ignored files from git tracking" "normal" "git"
}

# --- Script Entry Point ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi