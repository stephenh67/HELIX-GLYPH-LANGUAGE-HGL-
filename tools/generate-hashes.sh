#!/usr/bin/env bash

# SPDX-License-Identifier: Apache-2.0
# Generate SHA256 manifest for HGL release artifacts
#
# Usage:
#   ./generate-hashes.sh <release_dir>
#
# Example:
#   ./generate-hashes.sh releases/HGL-v1.2-beta.1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
COLOR_RESET='\033[0m'
COLOR_GREEN='\033[32m'
COLOR_YELLOW='\033[33m'
COLOR_RED='\033[31m'
COLOR_CYAN='\033[36m'

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

usage() {
    cat <<EOF
Usage: $0 <release_dir> [options]

Generate SHA256 manifest for HGL release artifacts.

Options:
  --sign              Sign the manifest with SSH key
  --key PATH          Path to SSH private key (default: ~/.ssh/hgl_release_key)
  --no-sort           Don't sort files alphabetically
  --output FILE       Output file (default: <release_dir>/SHA256SUMS.txt)
  -h, --help          Show this help message

Examples:
  # Generate unsigned manifest
  $0 releases/HGL-v1.2-beta.1

  # Generate and sign manifest
  $0 releases/HGL-v1.2-beta.1 --sign

  # Sign with specific key
  $0 releases/HGL-v1.2-beta.1 --sign --key ~/.ssh/custom_key

Exit Codes:
  0   Success
  1   Invalid arguments
  2   Release directory not found
  3   No files to hash
  4   Hash generation failed
  5   Signing failed
EOF
}

# Parse arguments
RELEASE_DIR=""
SIGN=false
SSH_KEY="$HOME/.ssh/hgl_release_key"
SORT_FILES=true
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --sign)
            SIGN=true
            shift
            ;;
        --key)
            SSH_KEY="$2"
            shift 2
            ;;
        --no-sort)
            SORT_FILES=false
            shift
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            if [[ -z "$RELEASE_DIR" ]]; then
                RELEASE_DIR="$1"
            else
                log_error "Multiple release directories specified"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ -z "$RELEASE_DIR" ]]; then
    log_error "Release directory not specified"
    usage
    exit 1
fi

if [[ ! -d "$RELEASE_DIR" ]]; then
    log_error "Release directory not found: $RELEASE_DIR"
    exit 2
fi

# Set default output file
if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="$RELEASE_DIR/SHA256SUMS.txt"
fi

# Check for signing prerequisites
if [[ "$SIGN" == true ]]; then
    if [[ ! -f "$SSH_KEY" ]]; then
        log_error "SSH key not found: $SSH_KEY"
        log_info "Generate a key with: ssh-keygen -t ed25519 -f $SSH_KEY"
        exit 5
    fi
    
    if ! command -v ssh-keygen &> /dev/null; then
        log_error "ssh-keygen not found - required for signing"
        exit 5
    fi
fi

# Generate manifest
log_info "Generating SHA256 manifest for: $RELEASE_DIR"
echo

# Create temporary file
TEMP_MANIFEST=$(mktemp)
trap "rm -f $TEMP_MANIFEST" EXIT

# Find files to hash (exclude the manifest itself and signatures)
FILES=()
while IFS= read -r -d '' file; do
    # Skip the manifest file itself and signature files
    basename=$(basename "$file")
    if [[ "$basename" != "SHA256SUMS.txt" ]] && \
       [[ "$basename" != "SHA256SUMS.txt.sig" ]] && \
       [[ "$basename" != *.sig ]]; then
        FILES+=("$file")
    fi
done < <(find "$RELEASE_DIR" -type f -print0)

if [[ ${#FILES[@]} -eq 0 ]]; then
    log_error "No files found to hash in: $RELEASE_DIR"
    exit 3
fi

log_info "Found ${#FILES[@]} files to hash"

# Sort files if requested
if [[ "$SORT_FILES" == true ]]; then
    IFS=$'\n' FILES=($(sort <<<"${FILES[*]}"))
fi

# Generate hashes
HASH_COUNT=0
for file in "${FILES[@]}"; do
    # Get relative path from release directory
    rel_path="${file#$RELEASE_DIR/}"
    
    # Compute hash
    if command -v sha256sum &> /dev/null; then
        hash=$(sha256sum "$file" | cut -d' ' -f1)
    elif command -v shasum &> /dev/null; then
        hash=$(shasum -a 256 "$file" | cut -d' ' -f1)
    else
        log_error "Neither sha256sum nor shasum found"
        exit 4
    fi
    
    # Write to manifest
    echo "$hash  $rel_path" >> "$TEMP_MANIFEST"
    HASH_COUNT=$((HASH_COUNT + 1))
    
    # Progress indicator
    if (( HASH_COUNT % 10 == 0 )); then
        echo -n "."
    fi
done

echo
log_success "Generated $HASH_COUNT hashes"

# Move manifest to final location
mv "$TEMP_MANIFEST" "$OUTPUT_FILE"
log_success "Manifest saved to: $OUTPUT_FILE"

# Sign manifest if requested
if [[ "$SIGN" == true ]]; then
    log_info "Signing manifest..."
    
    SIG_FILE="${OUTPUT_FILE}.sig"
    
    rm -f "$SIG_FILE"
    rm -f "$SIG_FILE"
    if ssh-keygen -Y sign -f "$SSH_KEY" -n file "$OUTPUT_FILE" 2>/dev/null; then
        log_success "Signature saved to: $SIG_FILE"
        
        # Display key fingerprint
        KEY_FP=$(ssh-keygen -lf "$SSH_KEY" | awk '{print $2}')
        log_info "Key fingerprint: $KEY_FP"
    else
        log_error "Failed to sign manifest"
        exit 5
    fi
fi

echo
log_success "Done!"

# Print manifest summary
echo
echo "=== Manifest Summary ==="
echo "Location: $OUTPUT_FILE"
echo "Files:    $HASH_COUNT"
echo "Size:     $(wc -c < "$OUTPUT_FILE") bytes"

if [[ "$SIGN" == true ]]; then
    echo "Signed:   Yes ($SIG_FILE)"
else
    echo "Signed:   No"
fi

echo
log_info "Verify with: sha256sum -c $OUTPUT_FILE"
if [[ "$SIGN" == true ]]; then
    log_info "Verify signature with: ssh-keygen -Y verify -f .github/allowed_signers -I release@helixprojectai.com -n file -s $SIG_FILE < $OUTPUT_FILE"
fi

exit 0
