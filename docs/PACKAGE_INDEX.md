# HGL v1.2-beta.1 Package Index

**Version:** 1.0  
**Last Updated:** October 2025

Complete reference for all files in the HGL v1.2-beta.1 implementation package.

---

## Table of Contents

1. [File Listing](#file-listing)
2. [Verification Scripts](#verification-scripts)
3. [CI/CD Workflows](#cicd-workflows)
4. [Tools](#tools)
5. [Security Infrastructure](#security-infrastructure)
6. [Documentation](#documentation)
7. [Dependencies](#dependencies)
8. [Configuration Files](#configuration-files)

---

## File Listing

### Complete Inventory

| # | File Path | Size | Type | Purpose |
|---|-----------|------|------|---------|
| 1 | `tools/verify_and_eval.sh` | 850 lines | Bash | Unix verification script |
| 2 | `tools/verify_and_eval.ps1` | 950 lines | PowerShell | Windows verification script |
| 3 | `.github/workflows/verify_provenance.yml` | 350 lines | YAML | CI: Provenance validation |
| 4 | `.github/workflows/verify_signatures.yml` | 350 lines | YAML | CI: Signature verification |
| 5 | `.github/workflows/verify_policy.yml` | 450 lines | YAML | CI: Policy gate testing |
| 6 | `.github/workflows/reproducibility_smoke.yml` | 400 lines | YAML | CI: Reproducibility testing |
| 7 | `tools/generate_provenance.py` | 300 lines | Python | Provenance generator |
| 8 | `tools/generate-hashes.sh` | 250 lines | Bash | Hash generator with signing |
| 9 | `tools/pre-commit-hook` | 200 lines | Bash | Git pre-commit hook |
| 10 | `.github/allowed_signers` | 50 lines | Text | SSH public key registry |
| 11 | `docs/HGL_GAP_ANALYSIS.md` | 900 lines | Markdown | Gap analysis |
| 12 | `docs/IMPLEMENTATION_README.md` | 600 lines | Markdown | Usage guide |
| 13 | `docs/DEPLOYMENT_CHECKLIST.md` | 700 lines | Markdown | Deployment guide |
| 14 | `docs/PACKAGE_INDEX.md` | 650 lines | Markdown | This file |

**Total:** ~7,500 lines across 14 files

---

## Verification Scripts

### 1. `tools/verify_and_eval.sh`

**Purpose:** Cross-platform verification script for Linux/macOS

**Language:** Bash 4.0+

**Dependencies:**
- `bash` 4.0+
- `sha256sum` or `shasum`
- `ssh-keygen` (OpenSSH 8.0+)
- `jq` (optional, for pretty output)

**Key Functions:**
- `verify_hashes()` - Validates SHA256 checksums
- `verify_signature()` - Validates ED25519 signatures
- `evaluate_policy()` - Runs policy gate tests
- `check_provenance()` - Validates provenance.json

**Exit Codes:**
- `0` - All checks passed
- `1` - Hash verification failed
- `2` - Signature verification failed
- `3` - Policy evaluation failed
- `99` - Unexpected error

**Configuration:**
- Modify `ALLOWED_SIGNERS` variable to change path
- Set `VERBOSE=true` for debug output

**Example Usage:**
```bash
# Full verification
./tools/verify_and_eval.sh releases/HGL-v1.2-beta.1

# Skip policy evaluation
./tools/verify_and_eval.sh releases/HGL-v1.2-beta.1 --skip-policy

# Verbose output
VERBOSE=true ./tools/verify_and_eval.sh releases/HGL-v1.2-beta.1
```

---

### 2. `tools/verify_and_eval.ps1`

**Purpose:** Windows-native verification script

**Language:** PowerShell 5.1+

**Dependencies:**
- PowerShell 5.1+ (included in Windows 10+)
- `ssh-keygen.exe` (optional, for signature verification)

**Key Functions:**
- `Test-HashIntegrity` - Validates SHA256 checksums
- `Test-Signature` - Validates ED25519 signatures (requires ssh-keygen)
- `Invoke-PolicyEvaluation` - Runs policy gate tests
- `Test-Provenance` - Validates provenance.json

**Exit Codes:** Same as Bash version (0-3, 99)

**Configuration:**
- Use `-AllowedSignersPath` parameter to override default
- Use `-Verbose` for debug output

**Example Usage:**
```powershell
# Full verification
.\tools\verify_and_eval.ps1 -ReleaseDir "C:\releases\HGL-v1.2-beta.1"

# Skip policy evaluation
.\tools\verify_and_eval.ps1 -ReleaseDir "." -SkipPolicy

# Verbose output
.\tools\verify_and_eval.ps1 -ReleaseDir "." -Verbose
```

**Feature Parity:** 100% compatible with Bash version

---

## CI/CD Workflows

### 3. `.github/workflows/verify_provenance.yml`

**Purpose:** Automated provenance validation in CI/CD

**Triggers:**
- `push` to `main` or `develop`
- `pull_request` to `main`
- Git tags matching `v*`
- Manual workflow dispatch

**Jobs:**
1. **verify-provenance**
   - Validates JSON schema
   - Checks all SHA256 hashes
   - Verifies Git metadata

**Runs On:** `ubuntu-latest`

**Dependencies:**
- Python 3.11
- `jsonschema`
- `pyyaml`

**Outputs:**
- Validation report (pass/fail)
- List of any hash mismatches

**Runtime:** ~2-5 minutes

**Configuration:**
```yaml
# Customize validation rules
- name: Validate provenance schema
  env:
    STRICT_MODE: true  # Fail on warnings
```

---

### 4. `.github/workflows/verify_signatures.yml`

**Purpose:** Automated signature verification

**Triggers:**
- `push` to `main`
- `pull_request` to `main`
- Git tags matching `v*`
- Manual dispatch

**Jobs:**
1. **verify-signatures**
   - Finds all `.sig` files
   - Validates against `allowed_signers`
   - Reports invalid signatures

**Runs On:** `ubuntu-latest`

**Dependencies:**
- OpenSSH 8.0+ (`ssh-keygen`)
- `allowed_signers` file

**Outputs:**
- Signature validation status
- Key fingerprints used
- List of invalid signatures (if any)

**Runtime:** ~1-3 minutes

**Configuration:**
```yaml
# Customize allowed signers path
env:
  ALLOWED_SIGNERS: .github/allowed_signers
```

---

### 5. `.github/workflows/verify_policy.yml`

**Purpose:** Policy gate test matrix

**Triggers:**
- `push` to any branch
- `pull_request` to `main`
- Manual workflow dispatch

**Jobs:**
1. **policy-test-matrix**
   - Runs 8 test vectors
   - Tests all policy gates
   - Validates gate combinations

**Test Matrix:**
| Vector | Expected | Description |
|--------|----------|-------------|
| `all_pass` | PASS | All gates pass |
| `gate1_fail` | FAIL | Gate 1 fails |
| `gate2_fail` | FAIL | Gate 2 fails |
| `gate3_fail` | FAIL | Gate 3 fails |
| `gate4_fail` | FAIL | Gate 4 fails |
| `gate5_fail` | FAIL | Gate 5 fails |
| `multi_fail` | FAIL | Multiple gates fail |
| `all_fail` | FAIL | All gates fail |

**Runs On:** `ubuntu-latest`

**Dependencies:**
- Bash verification script
- Test vector files

**Runtime:** ~10-15 minutes (parallel)

**Configuration:**
```yaml
strategy:
  matrix:
    test-vector: [all_pass, gate1_fail, ...]
  fail-fast: false  # Run all tests even if one fails
```

---

### 6. `.github/workflows/reproducibility_smoke.yml`

**Purpose:** Verify build reproducibility

**Triggers:**
- Schedule: Weekly (Sundays at 00:00 UTC)
- Manual workflow dispatch

**Jobs:**
1. **reproducibility-test**
   - Clean Docker environment
   - Rebuild artifacts
   - Compare hashes with originals

**Runs On:** `ubuntu-latest`

**Dependencies:**
- Docker
- Build tools (varies by project)

**Outputs:**
- Reproducibility status (pass/fail)
- Hash comparison report
- Build logs

**Runtime:** ~20-30 minutes

**Configuration:**
```yaml
# Customize build environment
env:
  DOCKER_IMAGE: ubuntu:24.04
  BUILD_CMD: make reproducible-build
```

---

## Tools

### 7. `tools/generate_provenance.py`

**Purpose:** Generate provenance.json manifests

**Language:** Python 3.8+

**Dependencies:**
- Standard library only (no external packages)
- Git (for metadata extraction)

**Key Classes:**
- `ProvenanceGenerator` - Main generator class

**Key Methods:**
- `_get_git_info()` - Extracts Git metadata
- `_compute_hash()` - Computes SHA256 hashes
- `add_inputs()` - Adds input files to provenance
- `add_outputs()` - Adds output files to provenance
- `evaluate_policy()` - Runs policy evaluation

**Input:**
- Version number
- Release directory path
- Input directory path (optional)
- Tools directory path (optional)

**Output:**
- `provenance.json` file

**Example Output:**
```json
{
  "artifact": "HGL v1.2-beta.1",
  "model": "claude-opus-4-20250514",
  "route": "standard",
  "build_utc": "2025-10-23T12:00:00Z",
  "git": {
    "commit": "abc123...",
    "branch": "main",
    "remote": "https://github.com/...",
    "timestamp": "2025-10-23T11:55:00Z"
  },
  "inputs": [...],
  "outputs": [...],
  "tools": [...],
  "policy": {...}
}
```

**Error Handling:**
- Gracefully handles missing Git info
- Warns if directories not found
- Continues on non-fatal errors

---

### 8. `tools/generate-hashes.sh`

**Purpose:** Generate SHA256SUMS.txt and sign with ED25519

**Language:** Bash 4.0+

**Dependencies:**
- `sha256sum` or `shasum`
- `ssh-keygen` (for signing)

**Key Functions:**
- `generate_hashes()` - Computes SHA256 for all files
- `sign_manifest()` - Signs manifest with SSH key

**Input:**
- Release directory path
- SSH private key path (for signing)

**Output:**
- `SHA256SUMS.txt` file
- `SHA256SUMS.txt.sig` file (if `--sign` used)

**Example Output:**
```
abc123...  file1.txt
def456...  file2.txt
789ghi...  dir/file3.txt
```

**Options:**
- `--sign` - Sign the manifest
- `--key <path>` - Custom key path
- `--no-sort` - Don't sort files
- `--output <file>` - Custom output path

**Error Handling:**
- Validates release directory exists
- Checks for signing prerequisites
- Provides clear error messages

---

### 9. `tools/pre-commit-hook`

**Purpose:** Auto-regenerate manifests on commit

**Language:** Bash 4.0+

**Dependencies:**
- `generate-hashes.sh`
- `generate_provenance.py` (optional)

**Key Functions:**
- `detect_changed_releases()` - Finds changed release directories
- `regenerate_manifests()` - Updates SHA256SUMS.txt and provenance.json

**Behavior:**
1. Detects files in `releases/` being committed
2. Checks if manifests need regeneration
3. Regenerates if files are newer than manifests
4. Stages updated manifests for commit

**Installation:**
```bash
cp tools/pre-commit-hook .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Bypass (if needed):**
```bash
git commit --no-verify
```

**Configuration:**
- Modify `RELEASE_PATTERN` to change release directory detection
- Set `SKIP_PROVENANCE=true` to skip provenance regeneration

---

## Security Infrastructure

### 10. `.github/allowed_signers`

**Purpose:** SSH public key registry for signature verification

**Format:** OpenSSH authorized_keys format

**Structure:**
```
<principal> namespaces="<ns>" valid-after="<date>" valid-before="<date>" <key-type> <key-data>
```

**Example:**
```
release@helixprojectai.com namespaces="file" valid-after="20250101" valid-before="20260101" ssh-ed25519 AAAA...
```

**Fields:**
- **principal:** Email or identifier for key owner
- **namespaces:** Allowed signature namespaces (typically "file")
- **valid-after:** Key validity start date (YYYYMMDD)
- **valid-before:** Key validity end date (YYYYMMDD)
- **key-type:** SSH key algorithm (ssh-ed25519 recommended)
- **key-data:** Base64-encoded public key

**Key Rotation:**
1. Generate new key
2. Add to `allowed_signers` with new validity period
3. Update old key's `valid-before` date
4. Commit and push changes

**Best Practices:**
- Use ED25519 keys (stronger, faster than RSA)
- Set validity periods ~1 year
- Rotate keys annually
- Keep 2-3 months overlap during rotation
- Document key owners and roles

---

## Documentation

### 11. `docs/HGL_GAP_ANALYSIS.md`

**Purpose:** Comprehensive gap analysis

**Sections:**
1. Executive Summary
2. Gap Identification
3. Implementation Overview
4. Detailed Gap Analysis (8 gaps)
5. Verification Matrix
6. Remaining Limitations
7. Deployment Readiness
8. Success Metrics
9. Conclusion
10. Appendices

**Target Audience:**
- Project managers
- Technical leads
- Stakeholders

**Key Insights:**
- What was missing
- What was implemented
- How gaps were closed
- Current status

---

### 12. `docs/IMPLEMENTATION_README.md`

**Purpose:** User guide and reference

**Sections:**
1. Quick Start
2. Architecture Overview
3. Tool Reference
4. Common Workflows
5. Troubleshooting
6. Best Practices
7. FAQ

**Target Audience:**
- Developers
- DevOps engineers
- Release managers

**Key Content:**
- Usage examples
- Configuration options
- Common problems and solutions
- Workflow patterns

---

### 13. `docs/DEPLOYMENT_CHECKLIST.md`

**Purpose:** Step-by-step deployment guide

**Sections:**
1. Phase 0: Preparation (15 min)
2. Phase 1: File Installation (30 min)
3. Phase 2: Configuration (30 min)
4. Phase 3: Testing (1-2 hours)
5. Phase 4: Go Live (30 min)
6. Post-Deployment
7. Rollback Procedure

**Target Audience:**
- Deployment engineers
- DevOps teams
- System administrators

**Key Features:**
- Time estimates
- Checkboxes for tracking
- Rollback procedures
- Success criteria

---

### 14. `docs/PACKAGE_INDEX.md`

**Purpose:** Detailed file reference (this document)

**Sections:**
1. File Listing
2. Verification Scripts
3. CI/CD Workflows
4. Tools
5. Security Infrastructure
6. Documentation
7. Dependencies
8. Configuration Files

**Target Audience:**
- All users (reference)

---

## Dependencies

### System Requirements

#### Linux
- **OS:** Ubuntu 20.04+, Debian 11+, or equivalent
- **Bash:** 4.0+
- **Python:** 3.8+
- **OpenSSH:** 8.0+
- **Git:** 2.20+

**Install:**
```bash
sudo apt update
sudo apt install bash python3 openssh-client git
```

#### macOS
- **OS:** macOS 12+ (Monterey)
- **Bash:** 4.0+ (via Homebrew)
- **Python:** 3.8+
- **OpenSSH:** 8.0+ (included)
- **Git:** 2.20+ (included)

**Install:**
```bash
brew install bash python3
```

#### Windows
- **OS:** Windows 10+
- **PowerShell:** 5.1+ (included) or 7+
- **Python:** 3.8+ (optional, for provenance generation)
- **Git:** 2.20+
- **OpenSSH:** Optional (for signature verification)

**Install:**
```powershell
# Via Chocolatey
choco install python git openssh

# Via Winget
winget install Python.Python.3.11
winget install Git.Git
```

### Python Packages

**Required:** None (uses standard library only)

**Optional:**
- `jsonschema` - For provenance schema validation
- `pyyaml` - For YAML configuration (CI/CD only)

**Install:**
```bash
pip install jsonschema pyyaml
```

### GitHub Actions

**Required for CI/CD:**
- `actions/checkout@v4`
- `actions/setup-python@v5`

**Built-in runners:**
- `ubuntu-latest` (Ubuntu 22.04)

---

## Configuration Files

### Environment Variables

#### For Verification Scripts
```bash
# Override allowed_signers path
export HGL_ALLOWED_SIGNERS="/path/to/allowed_signers"

# Enable verbose output
export VERBOSE=true

# Skip specific checks
export SKIP_HASHES=true
export SKIP_SIGNATURE=true
export SKIP_POLICY=true
```

#### For CI/CD Workflows
```yaml
# In .github/workflows/*.yml
env:
  ALLOWED_SIGNERS: .github/allowed_signers
  STRICT_MODE: true
```

### Git Configuration

**Required for signing:**
```bash
# Set signing key
git config user.signingkey ~/.ssh/hgl_release_key

# Enable commit signing (optional)
git config commit.gpgsign true
```

**Pre-commit hook:**
```bash
# Enable pre-commit hook
cp tools/pre-commit-hook .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

---

## Quick Reference

### Common Commands
```bash
# Verify a release
./tools/verify_and_eval.sh releases/HGL-v1.2-beta.1

# Generate provenance
python tools/generate_provenance.py \
  --version 1.2-beta.1 \
  --release-dir releases/HGL-v1.2-beta.1

# Generate and sign hashes
./tools/generate-hashes.sh releases/HGL-v1.2-beta.1 --sign

# Install pre-commit hook
cp tools/pre-commit-hook .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### File Paths
```
.
├── .github/
│   ├── allowed_signers
│   └── workflows/
│       ├── verify_provenance.yml
│       ├── verify_signatures.yml
│       ├── verify_policy.yml
│       └── reproducibility_smoke.yml
├── docs/
│   ├── HGL_GAP_ANALYSIS.md
│   ├── IMPLEMENTATION_README.md
│   ├── DEPLOYMENT_CHECKLIST.md
│   └── PACKAGE_INDEX.md
└── tools/
    ├── generate-hashes.sh
    ├── generate_provenance.py
    ├── pre-commit-hook
    ├── verify_and_eval.ps1
    └── verify_and_eval.sh
```

---

## Support

**Documentation:**
- GitHub: https://github.com/helixprojectai/HGL
- Issues: https://github.com/helixprojectai/HGL/issues

**Contact:**
- Email: support@helixprojectai.com
- Security: security@helixprojectai.com

---

**Document End**
