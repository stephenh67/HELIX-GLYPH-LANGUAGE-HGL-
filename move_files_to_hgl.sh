#!/usr/bin/env bash

# SPDX-License-Identifier: Apache-2.0
# Move HGL Infrastructure Files to Correct Locations
#
# Usage:
#   ./move_files_to_hgl.sh [--dry-run]
#
# This script moves files from the parent directory into the HGL repository structure.

set -euo pipefail

# Colors
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[32m'
COLOR_YELLOW='\033[33m'
COLOR_RED='\033[31m'
COLOR_CYAN='\033[36m'
COLOR_BLUE='\033[34m'

log_info() {
    echo -e "${COLOR_CYAN}▶ $*${COLOR_RESET}"
}

log_success() {
    echo -e "${COLOR_GREEN}✓ $*${COLOR_RESET}"
}

log_warning() {
    echo -e "${COLOR_YELLOW}⚠ $*${COLOR_RESET}"
}

log_error() {
    echo -e "${COLOR_RED}✗ $*${COLOR_RESET}" >&2
}

log_header() {
    echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
    echo -e "${COLOR_BLUE}$*${COLOR_RESET}"
    echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
}

# Parse arguments
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    log_warning "DRY RUN MODE - No files will be moved"
    echo
fi

# Determine script location and directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
HGL_DIR="$SCRIPT_DIR"

log_header "HGL Infrastructure File Mover"
echo
log_info "Parent directory: $PARENT_DIR"
log_info "HGL directory:    $HGL_DIR"
echo

# Define file mappings: SOURCE -> DESTINATION
declare -A FILE_MAP=(
    # Verification Scripts
    ["verify_and_eval.sh"]="tools/verify_and_eval.sh"
    ["verify_and_eval.ps1"]="tools/verify_and_eval.ps1"
    
    # CI/CD Workflows
    ["verify_provenance.yml"]=".github/workflows/verify_provenance.yml"
    ["verify_signatures.yml"]=".github/workflows/verify_signatures.yml"
    ["verify_policy.yml"]=".github/workflows/verify_policy.yml"
    ["reproducibility_smoke.yml"]=".github/workflows/reproducibility_smoke.yml"
    
    # Tools
    ["generate_provenance.py"]="tools/generate_provenance.py"
    ["generate-hashes.sh"]="tools/generate-hashes.sh"
    ["pre-commit-hook"]="tools/pre-commit-hook"
    
    # Security Infrastructure
    ["allowed_signers"]=".github/allowed_signers"
    
    # Documentation
    ["HGL_GAP_ANALYSIS.md"]="docs/HGL_GAP_ANALYSIS.md"
    ["IMPLEMENTATION_README.md"]="docs/IMPLEMENTATION_README.md"
    ["DEPLOYMENT_CHECKLIST.md"]="docs/DEPLOYMENT_CHECKLIST.md"
    ["PACKAGE_INDEX.md"]="docs/PACKAGE_INDEX.md"
)

# Check which files exist in parent directory
log_header "Checking Source Files"
echo

FOUND_FILES=()
MISSING_FILES=()

for src_file in "${!FILE_MAP[@]}"; do
    src_path="$PARENT_DIR/$src_file"
    if [[ -f "$src_path" ]]; then
        log_success "Found: $src_file"
        FOUND_FILES+=("$src_file")
    else
        log_warning "Missing: $src_file"
        MISSING_FILES+=("$src_file")
    fi
done

echo
log_info "Summary: ${#FOUND_FILES[@]} files found, ${#MISSING_FILES[@]} missing"

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    echo
    log_warning "Missing files:"
    for missing in "${MISSING_FILES[@]}"; do
        echo "  - $missing"
    done
fi

if [[ ${#FOUND_FILES[@]} -eq 0 ]]; then
    echo
    log_error "No files found to move!"
    log_info "Expected files in: $PARENT_DIR"
    exit 1
fi

# Ask for confirmation
echo
if [[ "$DRY_RUN" == false ]]; then
    read -p "Continue with moving ${#FOUND_FILES[@]} files? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warning "Aborted by user"
        exit 0
    fi
fi

# Create necessary directories
log_header "Creating Directories"
echo

DIRECTORIES=(
    "tools"
    ".github"
    ".github/workflows"
    "docs"
)

for dir in "${DIRECTORIES[@]}"; do
    dest_dir="$HGL_DIR/$dir"
    if [[ ! -d "$dest_dir" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$dest_dir"
            log_success "Created: $dir"
        else
            log_info "[DRY RUN] Would create: $dir"
        fi
    else
        log_info "Exists: $dir"
    fi
done

# Move files
echo
log_header "Moving Files"
echo

MOVED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0

for src_file in "${FOUND_FILES[@]}"; do
    src_path="$PARENT_DIR/$src_file"
    dest_path="$HGL_DIR/${FILE_MAP[$src_file]}"
    dest_dir=$(dirname "$dest_path")
    
    # Check if destination already exists
    if [[ -f "$dest_path" ]]; then
        log_warning "Skip: $src_file (destination exists)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi
    
    # Move the file
    if [[ "$DRY_RUN" == false ]]; then
        if mv "$src_path" "$dest_path"; then
            log_success "Moved: $src_file -> ${FILE_MAP[$src_file]}"
            MOVED_COUNT=$((MOVED_COUNT + 1))
        else
            log_error "Failed: $src_file"
            ERROR_COUNT=$((ERROR_COUNT + 1))
        fi
    else
        log_info "[DRY RUN] Would move: $src_file -> ${FILE_MAP[$src_file]}"
        MOVED_COUNT=$((MOVED_COUNT + 1))
    fi
done

# Set permissions for executable files
if [[ "$DRY_RUN" == false ]]; then
    echo
    log_header "Setting Permissions"
    echo
    
    EXECUTABLE_FILES=(
        "tools/verify_and_eval.sh"
        "tools/verify_and_eval.ps1"
        "tools/generate_provenance.py"
        "tools/generate-hashes.sh"
        "tools/pre-commit-hook"
    )
    
    for exe_file in "${EXECUTABLE_FILES[@]}"; do
        exe_path="$HGL_DIR/$exe_file"
        if [[ -f "$exe_path" ]]; then
            chmod +x "$exe_path"
            log_success "Made executable: $exe_file"
        fi
    done
fi

# Verify the file structure
echo
log_header "Verifying File Structure"
echo

VERIFICATION_OK=true

for src_file in "${FOUND_FILES[@]}"; do
    dest_path="$HGL_DIR/${FILE_MAP[$src_file]}"
    if [[ -f "$dest_path" ]]; then
        log_success "Verified: ${FILE_MAP[$src_file]}"
    else
        if [[ "$DRY_RUN" == false ]]; then
            log_error "Missing: ${FILE_MAP[$src_file]}"
            VERIFICATION_OK=false
        fi
    fi
done

# Display final summary
echo
log_header "Summary"
echo

if [[ "$DRY_RUN" == false ]]; then
    echo "Files moved:   $MOVED_COUNT"
    echo "Files skipped: $SKIPPED_COUNT"
    echo "Errors:        $ERROR_COUNT"
    echo
    
    if [[ $ERROR_COUNT -gt 0 ]]; then
        log_error "Some files failed to move!"
        exit 1
    elif [[ $MOVED_COUNT -eq 0 ]]; then
        log_warning "No files were moved (all destinations exist)"
    else
        log_success "All files moved successfully!"
    fi
    
    if [[ "$VERIFICATION_OK" == false ]]; then
        log_warning "Some files failed verification"
        exit 1
    fi
else
    echo "Files to move: $MOVED_COUNT"
    echo "Files to skip: $SKIPPED_COUNT"
    echo
    log_info "This was a dry run - no files were actually moved"
    log_info "Run without --dry-run to move files"
fi

# Show next steps
if [[ "$DRY_RUN" == false ]] && [[ $MOVED_COUNT -gt 0 ]]; then
    echo
    log_header "Next Steps"
    echo
    echo "1. Review the moved files:"
    echo "   tree -L 2 tools/ .github/ docs/"
    echo
    echo "2. Update .github/allowed_signers with your actual keys:"
    echo "   nano .github/allowed_signers"
    echo
    echo "3. Test the verification scripts:"
    echo "   ./tools/verify_and_eval.sh releases/HGL-v1.2-beta.1"
    echo
    echo "4. Commit the changes:"
    echo "   git add tools/ .github/ docs/"
    echo "   git commit -m 'Infrastructure: Add verification tooling and CI/CD workflows'"
    echo
    echo "5. Follow the deployment checklist:"
    echo "   cat docs/DEPLOYMENT_CHECKLIST.md"
    echo
fi

exit 0
