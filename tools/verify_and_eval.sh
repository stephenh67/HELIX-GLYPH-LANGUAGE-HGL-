#!/usr/bin/env bash

# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 Helix AI Innovations Inc.
#
# HGL Verification and Policy Evaluation Script (Bash)
#
# Version: 1.2-beta.1
# Description:
#   Verifies HGL artifacts with:
#   - SHA256 hash validation
#   - ED25519 signature verification via ssh-keygen
#   - Policy gate evaluation (consent, privilege, temporal)
#   - Deterministic exit codes for CI/CD integration
#
# Usage:
#   verify_and_eval.sh <compiled.json> <proof.json> <allowed_signers> <identity> [namespace] [manifest_dir]
#
# Exit Codes:
#   0 - All checks passed
#   1 - Hash mismatch detected
#   2 - Signature verification failed
#   3 - Policy gate failed
#   4 - Missing required file
#   5 - Tool dependency not found
#   6 - Invalid input format
#   10 - Unexpected error

set -euo pipefail

# ═══════════════════════════════════════════════════════════
# Configuration & Constants
# ═══════════════════════════════════════════════════════════

VERSION="1.2-beta.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default parameters
DEFAULT_NAMESPACE="ttd-ledger-root-v0.1"
DEFAULT_MANIFEST_DIR="./manifests"

# Exit codes
EXIT_SUCCESS=0
EXIT_HASH_FAIL=1
EXIT_SIG_FAIL=2
EXIT_POLICY_FAIL=3
EXIT_FILE_MISSING=4
EXIT_TOOL_MISSING=5
EXIT_INVALID_INPUT=6
EXIT_UNEXPECTED=10

# ANSI color codes (disable if NO_COLOR is set or not a TTY)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    COLOR_RESET='\033[0m'
    COLOR_GREEN='\033[32m'
    COLOR_YELLOW='\033[33m'
    COLOR_RED='\033[31m'
    COLOR_CYAN='\033[36m'
    COLOR_BOLD='\033[1m'
else
    COLOR_RESET=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_RED=''
    COLOR_CYAN=''
    COLOR_BOLD=''
fi

# ═══════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════

log_header() {
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

die() {
    log_error "$1"
    exit "${2:-$EXIT_UNEXPECTED}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

find_jq() {
    # Check if jq is in PATH
    if command_exists jq; then
        echo "jq"
        return 0
    fi
    
    # Check for bundled jq in script directory
    if [[ -x "${SCRIPT_DIR}/jq" ]]; then
        echo "${SCRIPT_DIR}/jq"
        return 0
    fi
    
    # Check current directory
    if [[ -x "./jq" ]]; then
        echo "./jq"
        return 0
    fi
    
    return 1
}

usage() {
    cat <<EOF
Usage: $0 <compiled.json> <proof.json> <allowed_signers> <identity> [namespace] [manifest_dir]

Arguments:
  compiled.json     Path to compiled HGL JSON file
  proof.json        Path to synergy proof JSON file
  allowed_signers   Path to SSH allowed_signers file
  identity          Signer identity to verify (e.g., "ledger-root")
  namespace         SSH signature namespace (default: ${DEFAULT_NAMESPACE})
  manifest_dir      Directory with sha256sums.txt (default: ${DEFAULT_MANIFEST_DIR})

Example:
  $0 examples/001_consent_access.compiled.json \\
     examples/synergy_proof.sample.json \\
     ~/.ssh/allowed_signers \\
     ledger-root

Environment Variables:
  NO_COLOR          Disable colored output
  VERBOSE           Enable detailed diagnostic output

Exit Codes:
  0  - All checks passed
  1  - Hash mismatch
  2  - Signature verification failed
  3  - Policy gate failed
  4  - Missing required file
  5  - Tool dependency not found
  6  - Invalid input format
  10 - Unexpected error
EOF
}

# ═══════════════════════════════════════════════════════════
# Verification Functions
# ═══════════════════════════════════════════════════════════

verify_sha256_manifest() {
    local manifest_path="$1"
    shift
    local -a files_to_verify=("$@")
    
    log_header "Verifying SHA256 checksums..."
    
    if [[ ! -f "$manifest_path" ]]; then
        log_error "SHA256 manifest not found: $manifest_path"
        return 1
    fi
    
    local entry_count
    entry_count=$(grep -c '^[0-9a-f]\{64\}' "$manifest_path" || true)
    echo "  Manifest contains $entry_count entries"
    
    local all_match=true
    for file in "${files_to_verify[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "  File not found: $file"
            all_match=false
            continue
        fi
        
        # Get relative path (normalized for cross-platform)
        local rel_path
        rel_path=$(realpath --relative-to="." "$file" 2>/dev/null || echo "$file")
        
        # Get expected hash from manifest
        local expected_hash
        expected_hash=$(grep " ${rel_path}$" "$manifest_path" | awk '{print $1}' || true)
        
        if [[ -z "$expected_hash" ]]; then
            log_warning "  File not in manifest: $rel_path"
            continue
        fi
        
        # Calculate actual hash
        local actual_hash
        actual_hash=$(sha256sum "$file" | awk '{print $1}')
        
        if [[ "$actual_hash" == "$expected_hash" ]]; then
            log_success "  $rel_path"
            [[ -n "${VERBOSE:-}" ]] && echo "    Hash: $actual_hash"
        else
            log_error "  $rel_path (hash mismatch)"
            echo "    Expected: $expected_hash"
            echo "    Actual:   $actual_hash"
            all_match=false
        fi
    done
    
    $all_match
}

verify_ed25519_signature() {
    local manifest_path="$1"
    local signature_path="$2"
    local allowed_signers="$3"
    local identity="$4"
    local namespace="$5"
    
    log_header "Verifying ED25519 signature..."
    
    # Check required files
    [[ -f "$manifest_path" ]] || die "Manifest not found: $manifest_path" $EXIT_FILE_MISSING
    [[ -f "$signature_path" ]] || die "Signature not found: $signature_path" $EXIT_FILE_MISSING
    [[ -f "$allowed_signers" ]] || die "Allowed signers not found: $allowed_signers" $EXIT_FILE_MISSING
    
    # Check for ssh-keygen
    if ! command_exists ssh-keygen; then
        die "ssh-keygen not found in PATH. Install OpenSSH." $EXIT_TOOL_MISSING
    fi
    
    echo "  Identity: $identity"
    echo "  Namespace: $namespace"
    
    # Run ssh-keygen verify (reads manifest from stdin)
    if ssh-keygen -Y verify \
        -f "$allowed_signers" \
        -I "$identity" \
        -n "$namespace" \
        -s "$signature_path" \
        < "$manifest_path" >/dev/null 2>&1; then
        log_success "Signature valid"
        return 0
    else
        log_error "Signature verification failed"
        return 1
    fi
}

evaluate_policy_gates() {
    local compiled_json="$1"
    local proof_json="$2"
    local jq_cmd="${3:-jq}"
    
    log_header "Evaluating policy gates..."
    
    local policy_passed=true
    local -a policy_gates=()
    local -a policy_errors=()
    
    # Gate 1: Consent Required
    echo "  Checking: consent.required"
    local has_consent
    has_consent=$("$jq_cmd" -e '.consent' "$compiled_json" >/dev/null 2>&1 && echo "true" || echo "false")
    
    if [[ "$has_consent" == "true" ]]; then
        log_success "  consent.required: PASS"
        policy_gates+=("consent.required:pass")
    else
        log_error "  consent.required: FAIL"
        policy_passed=false
        policy_gates+=("consent.required:fail:consent.missing_scope")
        policy_errors+=("consent.missing_scope")
    fi
    
    # Gate 2: Least Privilege
    echo "  Checking: least_privilege"
    local priv_level
    priv_level=$("$jq_cmd" -r '.privilege_level // "undefined"' "$compiled_json" 2>/dev/null)
    
    case "$priv_level" in
        read|read-only|minimal|undefined)
            log_success "  least_privilege: PASS"
            policy_gates+=("least_privilege:pass")
            ;;
        admin|root|write-all)
            log_error "  least_privilege: FAIL (escalation detected: $priv_level)"
            policy_passed=false
            policy_gates+=("least_privilege:fail:privilege.escalation")
            policy_errors+=("privilege.escalation")
            ;;
        *)
            log_warning "  least_privilege: PASS (default)"
            policy_gates+=("least_privilege:pass:default")
            ;;
    esac
    
    # Gate 3: Temporal Validity
    echo "  Checking: temporal.validity"
    local has_temporal
    has_temporal=$("$jq_cmd" -e '.temporal' "$compiled_json" >/dev/null 2>&1 && echo "true" || echo "false")
    
    if [[ "$has_temporal" == "true" ]]; then
        local grant_time expiry_time
        grant_time=$("$jq_cmd" -r '.temporal.grant_time' "$compiled_json" 2>/dev/null)
        expiry_time=$("$jq_cmd" -r '.temporal.expiry_time' "$compiled_json" 2>/dev/null)
        
        if [[ -n "$grant_time" && -n "$expiry_time" ]]; then
            local grant_epoch expiry_epoch current_epoch
            grant_epoch=$(date -d "$grant_time" +%s 2>/dev/null || echo "0")
            expiry_epoch=$(date -d "$expiry_time" +%s 2>/dev/null || echo "0")
            current_epoch=$(date +%s)
            
            if [[ $grant_epoch -gt 0 && $expiry_epoch -gt 0 ]]; then
                if [[ $current_epoch -ge $grant_epoch && $current_epoch -le $expiry_epoch ]]; then
                    log_success "  temporal.validity: PASS (within window)"
                    policy_gates+=("temporal.validity:pass")
                else
                    log_error "  temporal.validity: FAIL (outside valid window)"
                    policy_passed=false
                    policy_gates+=("temporal.validity:fail:consent.expired")
                    policy_errors+=("consent.expired")
                fi
            else
                log_warning "  temporal.validity: SKIP (invalid timestamp format)"
                policy_gates+=("temporal.validity:skip")
            fi
        else
            log_warning "  temporal.validity: SKIP (missing timestamps)"
            policy_gates+=("temporal.validity:skip")
        fi
    else
        log_warning "  temporal.validity: SKIP (no temporal constraints)"
        policy_gates+=("temporal.validity:skip")
    fi
    
    # Gate 4: Tenant Isolation
    echo "  Checking: tenant.isolation"
    local compiled_tenant proof_tenant
    compiled_tenant=$("$jq_cmd" -r '.tenant_id // "none"' "$compiled_json" 2>/dev/null)
    proof_tenant=$("$jq_cmd" -r '.tenant_id // "none"' "$proof_json" 2>/dev/null)
    
    if [[ "$compiled_tenant" != "none" && "$proof_tenant" != "none" ]]; then
        if [[ "$compiled_tenant" == "$proof_tenant" ]]; then
            log_success "  tenant.isolation: PASS"
            policy_gates+=("tenant.isolation:pass")
        else
            log_error "  tenant.isolation: FAIL (tenant mismatch)"
            policy_passed=false
            policy_gates+=("tenant.isolation:fail:consent.tenant_mismatch")
            policy_errors+=("consent.tenant_mismatch")
        fi
    else
        log_warning "  tenant.isolation: SKIP (no tenant_id specified)"
        policy_gates+=("tenant.isolation:skip")
    fi
    
    # Gate 5: Proof Integrity
    echo "  Checking: proof.integrity"
    local has_signature has_timestamp has_hash
    has_signature=$("$jq_cmd" -e '.signature' "$proof_json" >/dev/null 2>&1 && echo "true" || echo "false")
    has_timestamp=$("$jq_cmd" -e '.timestamp' "$proof_json" >/dev/null 2>&1 && echo "true" || echo "false")
    has_hash=$("$jq_cmd" -e '.hash' "$proof_json" >/dev/null 2>&1 && echo "true" || echo "false")
    
    if [[ "$has_signature" == "true" && "$has_timestamp" == "true" && "$has_hash" == "true" ]]; then
        log_success "  proof.integrity: PASS"
        policy_gates+=("proof.integrity:pass")
    else
        local -a missing_fields=()
        [[ "$has_signature" != "true" ]] && missing_fields+=("signature")
        [[ "$has_timestamp" != "true" ]] && missing_fields+=("timestamp")
        [[ "$has_hash" != "true" ]] && missing_fields+=("hash")
        
        if [[ ${#missing_fields[@]} -gt 0 ]]; then
            log_error "  proof.integrity: FAIL (missing fields: ${missing_fields[*]})"
            policy_passed=false
            policy_gates+=("proof.integrity:fail:proof.integrity")
            policy_errors+=("proof.integrity")
        else
            log_warning "  proof.integrity: SKIP"
            policy_gates+=("proof.integrity:skip")
        fi
    fi
    
    # Export results for JSON output
    export POLICY_PASSED="$policy_passed"
    export POLICY_GATES="${policy_gates[*]}"
    export POLICY_ERRORS="${policy_errors[*]}"
    
    $policy_passed
}

# ═══════════════════════════════════════════════════════════
# Main Execution
# ═══════════════════════════════════════════════════════════

main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  HGL Verification & Policy Evaluation (Bash)"
    echo "  Version: $VERSION"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Parse arguments
    if [[ $# -lt 4 ]]; then
        usage
        exit $EXIT_INVALID_INPUT
    fi
    
    local compiled_file="$1"
    local proof_file="$2"
    local allowed_signers="$3"
    local identity="$4"
    local namespace="${5:-$DEFAULT_NAMESPACE}"
    local manifest_dir="${6:-$DEFAULT_MANIFEST_DIR}"
    
    # Find jq
    local jq_cmd
    if jq_cmd=$(find_jq); then
        echo "Using jq: $jq_cmd"
    else
        log_warning "jq not found - some policy checks may be limited"
        log_warning "Install jq: https://stedolan.github.io/jq/"
        jq_cmd="jq"  # Will fail if actually called, but script continues where possible
    fi
    echo ""
    
    # Verify required files exist
    log_header "Checking required files..."
    
    [[ -f "$compiled_file" ]] || die "Compiled HGL not found: $compiled_file" $EXIT_FILE_MISSING
    log_success "Compiled HGL: $compiled_file"
    
    [[ -f "$proof_file" ]] || die "Proof file not found: $proof_file" $EXIT_FILE_MISSING
    log_success "Proof file: $proof_file"
    
    [[ -f "$allowed_signers" ]] || die "Allowed signers not found: $allowed_signers" $EXIT_FILE_MISSING
    log_success "Allowed signers: $allowed_signers"
    
    echo ""
    
    # Step 1: SHA256 Verification
    local manifest_path="${manifest_dir}/sha256sums.txt"
    local signature_path="${manifest_dir}/sha256sums.txt.sig"
    
    local hash_check_passed=false
    if verify_sha256_manifest "$manifest_path" "$compiled_file" "$proof_file"; then
        hash_check_passed=true
    fi
    echo ""
    
    if ! $hash_check_passed; then
        log_error "Hash verification failed - aborting"
        echo ""
        exit $EXIT_HASH_FAIL
    fi
    
    # Step 2: Signature Verification
    local sig_check_passed=false
    if verify_ed25519_signature "$manifest_path" "$signature_path" "$allowed_signers" "$identity" "$namespace"; then
        sig_check_passed=true
    fi
    echo ""
    
    if ! $sig_check_passed; then
        log_error "Signature verification failed - aborting"
        echo ""
        exit $EXIT_SIG_FAIL
    fi
    
    # Step 3: Policy Evaluation
    local policy_check_passed=false
    if command_exists "$jq_cmd" && evaluate_policy_gates "$compiled_file" "$proof_file" "$jq_cmd"; then
        policy_check_passed=true
    fi
    echo ""
    
    # Step 4: Generate JSON output
    log_header "Verification Summary"
    
    local overall_passed=false
    if $hash_check_passed && $sig_check_passed && $policy_check_passed; then
        overall_passed=true
    fi
    
    # Build policy gates JSON array
    local gates_json="["
    IFS=' ' read -ra gates_array <<< "$POLICY_GATES"
    for i in "${!gates_array[@]}"; do
        IFS=':' read -ra gate_parts <<< "${gates_array[$i]}"
        gates_json+="{"
        gates_json+="\"gate\":\"${gate_parts[0]}\","
        gates_json+="\"status\":\"${gate_parts[1]}\""
        [[ -n "${gate_parts[2]:-}" ]] && gates_json+=",\"error_code\":\"${gate_parts[2]}\""
        gates_json+="}"
        [[ $i -lt $((${#gates_array[@]} - 1)) ]] && gates_json+=","
    done
    gates_json+="]"
    
    # Build errors JSON array
    local errors_json="["
    IFS=' ' read -ra errors_array <<< "$POLICY_ERRORS"
    for i in "${!errors_array[@]}"; do
        errors_json+="\"${errors_array[$i]}\""
        [[ $i -lt $((${#errors_array[@]} - 1)) ]] && errors_json+=","
    done
    errors_json+="]"
    
    # Generate complete JSON output
    cat <<JSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "$VERSION",
  "passed": $overall_passed,
  "checks": {
    "hash_verification": $hash_check_passed,
    "signature_verification": $sig_check_passed,
    "policy_evaluation": $policy_check_passed
  },
  "policy": {
    "status": "$(if $policy_check_passed; then echo pass; else echo fail; fi)",
    "gates": $gates_json,
    "errors": $errors_json
  },
  "files": {
    "compiled": "$compiled_file",
    "proof": "$proof_file",
    "manifest": "$manifest_path",
    "signature": "$signature_path"
  },
  "signer": {
    "identity": "$identity",
    "namespace": "$namespace"
  }
}
JSON
    
    echo ""
    
    # Final status
    if $overall_passed; then
        echo -e "${COLOR_GREEN}═══════════════════════════════════════════════════════════${COLOR_RESET}"
        echo -e "${COLOR_GREEN}  ✓ ALL CHECKS PASSED${COLOR_RESET}"
        echo -e "${COLOR_GREEN}═══════════════════════════════════════════════════════════${COLOR_RESET}"
        exit $EXIT_SUCCESS
    else
        echo -e "${COLOR_RED}═══════════════════════════════════════════════════════════${COLOR_RESET}"
        echo -e "${COLOR_RED}  ✗ VERIFICATION FAILED${COLOR_RESET}"
        echo -e "${COLOR_RED}═══════════════════════════════════════════════════════════${COLOR_RESET}"
        
        if ! $hash_check_passed; then
            exit $EXIT_HASH_FAIL
        elif ! $sig_check_passed; then
            exit $EXIT_SIG_FAIL
        elif ! $policy_check_passed; then
            exit $EXIT_POLICY_FAIL
        fi
    fi
}

# Handle script errors
trap 'die "Unexpected error at line $LINENO" $EXIT_UNEXPECTED' ERR

# Execute main
main "$@"
