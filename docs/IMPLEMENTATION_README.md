# HGL v1.2-beta.1 Implementation Guide

**Version:** 1.0  
**Last Updated:** October 2025  
**Audience:** Developers, DevOps Engineers, Release Managers

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Tool Reference](#tool-reference)
4. [Common Workflows](#common-workflows)
5. [Troubleshooting](#troubleshooting)
6. [Best Practices](#best-practices)
7. [FAQ](#faq)

---

## Quick Start

### For Users (Verifying Releases)

**Linux/macOS:**
```bash
# Download release
wget https://github.com/helixprojectai/HGL/releases/download/v1.2-beta.1/HGL-v1.2-beta.1.tar.gz

# Extract
tar -xzf HGL-v1.2-beta.1.tar.gz
cd HGL-v1.2-beta.1

# Verify
./tools/verify_and_eval.sh .
```

**Windows:**
```powershell
# Download release (use browser or curl)
# Extract to C:\HGL-v1.2-beta.1

# Verify
cd C:\HGL-v1.2-beta.1
.\tools\verify_and_eval.ps1 .
```

### For Developers (Creating Releases)
```bash
# 1. Create release directory
mkdir -p releases/HGL-v1.3-beta.1

# 2. Copy artifacts
cp dist/* releases/HGL-v1.3-beta.1/

# 3. Generate provenance
python tools/generate_provenance.py \
  --version 1.3-beta.1 \
  --release-dir releases/HGL-v1.3-beta.1

# 4. Generate and sign hashes
./tools/generate-hashes.sh releases/HGL-v1.3-beta.1 --sign

# 5. Commit (pre-commit hook will verify)
git add releases/HGL-v1.3-beta.1
git commit -m "Release: HGL v1.3-beta.1"
git push origin main
```

---

## Architecture Overview

### Component Hierarchy
```
HGL Release Infrastructure
├── Verification Layer
│   ├── verify_and_eval.sh (Bash)
│   └── verify_and_eval.ps1 (PowerShell)
│
├── CI/CD Layer
│   ├── verify_provenance.yml
│   ├── verify_signatures.yml
│   ├── verify_policy.yml
│   └── reproducibility_smoke.yml
│
├── Tooling Layer
│   ├── generate_provenance.py
│   ├── generate-hashes.sh
│   └── pre-commit-hook
│
├── Security Layer
│   └── allowed_signers
│
└── Documentation Layer
    ├── HGL_GAP_ANALYSIS.md
    ├── IMPLEMENTATION_README.md (this file)
    ├── DEPLOYMENT_CHECKLIST.md
    └── PACKAGE_INDEX.md
```

### Data Flow
```
Development → Tools → Artifacts → CI/CD → Verification → Release
    ↓           ↓         ↓          ↓          ↓          ↓
  Code    Provenance  Manifests   Tests    Signatures  Download
          Hashes      Signatures  Gates    Validation  Verify
```

---

## Tool Reference

### 1. Verification Scripts

#### `verify_and_eval.sh` (Bash)

**Purpose:** Verify HGL releases on Linux/macOS

**Usage:**
```bash
./verify_and_eval.sh <release_dir> [options]
```

**Options:**
- `--skip-hashes` - Skip SHA256 verification
- `--skip-sig` - Skip signature verification
- `--skip-policy` - Skip policy gate evaluation
- `--verbose` - Show detailed output
- `--help` - Show help message

**Exit Codes:**
- `0` - All checks passed
- `1` - Hash verification failed
- `2` - Signature verification failed
- `3` - Policy gate failed
- `99` - Unexpected error

**Examples:**
```bash
# Full verification
./verify_and_eval.sh releases/HGL-v1.2-beta.1

# Quick check (skip policy)
./verify_and_eval.sh releases/HGL-v1.2-beta.1 --skip-policy

# Verbose output
./verify_and_eval.sh releases/HGL-v1.2-beta.1 --verbose
```

#### `verify_and_eval.ps1` (PowerShell)

**Purpose:** Verify HGL releases on Windows

**Usage:**
```powershell
.\verify_and_eval.ps1 -ReleaseDir <path> [options]
```

**Options:**
- `-SkipHashes` - Skip SHA256 verification
- `-SkipSignature` - Skip signature verification
- `-SkipPolicy` - Skip policy gate evaluation
- `-Verbose` - Show detailed output
- `-Help` - Show help message

**Exit Codes:** Same as Bash version

**Examples:**
```powershell
# Full verification
.\verify_and_eval.ps1 -ReleaseDir "C:\HGL-v1.2-beta.1"

# Quick check
.\verify_and_eval.ps1 -ReleaseDir "C:\HGL-v1.2-beta.1" -SkipPolicy

# Verbose
.\verify_and_eval.ps1 -ReleaseDir "C:\HGL-v1.2-beta.1" -Verbose
```

---

### 2. Provenance Generator

#### `generate_provenance.py`

**Purpose:** Generate provenance.json manifests for releases

**Dependencies:**
- Python 3.8+
- Standard library only (no external packages)

**Usage:**
```bash
python generate_provenance.py \
  --version <version> \
  --release-dir <path> \
  [options]
```

**Required Arguments:**
- `--version` - Release version (e.g., "1.2-beta.1")
- `--release-dir` - Path to release directory

**Optional Arguments:**
- `--input-dir <path>` - Input source directory (default: src/)
- `--tools-dir <path>` - Tools directory (default: tools/)
- `--route <name>` - Processing route: standard/extended/constitutional (default: standard)
- `--no-policy` - Skip policy evaluation
- `--output <path>` - Output file path (default: <release-dir>/provenance.json)
- `--print` - Print to stdout instead of saving

**Examples:**
```bash
# Basic usage
python tools/generate_provenance.py \
  --version 1.2-beta.1 \
  --release-dir releases/HGL-v1.2-beta.1

# Custom input directory
python tools/generate_provenance.py \
  --version 1.2-beta.1 \
  --release-dir releases/HGL-v1.2-beta.1 \
  --input-dir src/v1.2

# Skip policy evaluation (faster)
python tools/generate_provenance.py \
  --version 1.2-beta.1 \
  --release-dir releases/HGL-v1.2-beta.1 \
  --no-policy

# Print to stdout
python tools/generate_provenance.py \
  --version 1.2-beta.1 \
  --release-dir releases/HGL-v1.2-beta.1 \
  --print | jq .
```

**Output Format:**
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
  "policy": {
    "version": "v1.2",
    "status": "pass",
    "evaluation_utc": "2025-10-23T12:00:05Z",
    "gates": {...}
  }
}
```

---

### 3. Hash Generator

#### `generate-hashes.sh`

**Purpose:** Generate SHA256SUMS.txt manifests and sign them

**Dependencies:**
- Bash 4.0+
- `sha256sum` or `shasum`
- `ssh-keygen` (for signing)

**Usage:**
```bash
./generate-hashes.sh <release_dir> [options]
```

**Options:**
- `--sign` - Sign the manifest with SSH key
- `--key <path>` - Path to SSH private key (default: ~/.ssh/hgl_release_key)
- `--no-sort` - Don't sort files alphabetically
- `--output <file>` - Output file (default: <release_dir>/SHA256SUMS.txt)
- `-h, --help` - Show help message

**Exit Codes:**
- `0` - Success
- `1` - Invalid arguments
- `2` - Release directory not found
- `3` - No files to hash
- `4` - Hash generation failed
- `5` - Signing failed

**Examples:**
```bash
# Generate unsigned manifest
./tools/generate-hashes.sh releases/HGL-v1.2-beta.1

# Generate and sign
./tools/generate-hashes.sh releases/HGL-v1.2-beta.1 --sign

# Use custom key
./tools/generate-hashes.sh releases/HGL-v1.2-beta.1 \
  --sign \
  --key ~/.ssh/custom_release_key

# Custom output location
./tools/generate-hashes.sh releases/HGL-v1.2-beta.1 \
  --output /tmp/checksums.txt
```

**Output Format:**
```
abc123...  file1.txt
def456...  file2.txt
789ghi...  subdir/file3.txt
```

---

### 4. Pre-commit Hook

#### `pre-commit-hook`

**Purpose:** Auto-regenerate manifests when release files change

**Installation:**
```bash
cp tools/pre-commit-hook .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Behavior:**
1. Detects changed files in `releases/` directories
2. Regenerates SHA256SUMS.txt if needed
3. Regenerates provenance.json if needed
4. Stages updated manifests for commit
5. Allows commit to proceed

**Configuration:** None required (auto-detects changes)

**Disabling (if needed):**
```bash
# Temporarily disable
git commit --no-verify

# Permanently disable
rm .git/hooks/pre-commit
```

---

## Common Workflows

### Workflow 1: Creating a New Release
```bash
# Step 1: Create release branch
git checkout -b release/v1.3-beta.1

# Step 2: Create release directory
mkdir -p releases/HGL-v1.3-beta.1

# Step 3: Build and copy artifacts
make build
cp dist/* releases/HGL-v1.3-beta.1/

# Step 4: Generate provenance
python tools/generate_provenance.py \
  --version 1.3-beta.1 \
  --release-dir releases/HGL-v1.3-beta.1

# Step 5: Generate and sign hashes
./tools/generate-hashes.sh releases/HGL-v1.3-beta.1 --sign

# Step 6: Commit (pre-commit hook will verify)
git add releases/HGL-v1.3-beta.1
git commit -m "Release: HGL v1.3-beta.1"

# Step 7: Push and create PR
git push origin release/v1.3-beta.1
# Create PR on GitHub

# Step 8: After PR approval, tag release
git checkout main
git pull
git tag -a v1.3-beta.1 -m "HGL v1.3-beta.1"
git push origin v1.3-beta.1
```

### Workflow 2: Verifying a Downloaded Release
```bash
# Step 1: Download and extract
wget https://github.com/.../HGL-v1.2-beta.1.tar.gz
tar -xzf HGL-v1.2-beta.1.tar.gz
cd HGL-v1.2-beta.1

# Step 2: Run verification
./tools/verify_and_eval.sh .

# Step 3: Check exit code
if [ $? -eq 0 ]; then
  echo "✅ Verification passed"
else
  echo "❌ Verification failed"
  exit 1
fi

# Step 4: Use the release
# ... your workflow here ...
```

### Workflow 3: Updating an Existing Release
```bash
# Step 1: Checkout release directory
cd releases/HGL-v1.2-beta.1

# Step 2: Update files
# ... make changes ...

# Step 3: Pre-commit hook will auto-regenerate manifests
git add .
git commit -m "Update: Fix typo in documentation"

# Step 4: Push
git push origin main

# Note: CI/CD will automatically verify the updated release
```

### Workflow 4: Rotating Signing Keys
```bash
# Step 1: Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/hgl_release_key_2025 \
  -C "release@helixprojectai.com"

# Step 2: Add new key to allowed_signers
cat >> .github/allowed_signers <<EOF
release@helixprojectai.com namespaces="file" valid-after="20250101" valid-before="20260101" $(cat ~/.ssh/hgl_release_key_2025.pub | cut -d' ' -f1-2)
EOF

# Step 3: Update old key expiration in allowed_signers
# Edit .github/allowed_signers and set valid-before="20250131" for old key

# Step 4: Commit and push
git add .github/allowed_signers
git commit -m "Security: Rotate release signing key"
git push origin main

# Step 5: Use new key for future releases
./tools/generate-hashes.sh releases/HGL-v1.3-beta.1 \
  --sign \
  --key ~/.ssh/hgl_release_key_2025
```

---

## Troubleshooting

### Issue: Verification script not executable

**Symptoms:**
```bash
bash: ./verify_and_eval.sh: Permission denied
```

**Solution:**
```bash
chmod +x tools/verify_and_eval.sh
chmod +x tools/verify_and_eval.ps1
```

---

### Issue: Hash verification fails

**Symptoms:**
```
✗ Hash verification failed for: file.txt
Expected: abc123...
Got:      def456...
```

**Causes:**
1. File was modified after manifest was generated
2. Manifest is outdated
3. File corruption during download

**Solutions:**
```bash
# Option 1: Regenerate manifest
./tools/generate-hashes.sh releases/HGL-v1.2-beta.1

# Option 2: Re-download the release
rm -rf HGL-v1.2-beta.1
wget https://github.com/.../HGL-v1.2-beta.1.tar.gz
tar -xzf HGL-v1.2-beta.1.tar.gz

# Option 3: Check if file was intentionally modified
git log --follow -- releases/HGL-v1.2-beta.1/file.txt
```

---

### Issue: Signature verification fails

**Symptoms:**
```
✗ Signature verification failed
Could not find allowed key
```

**Causes:**
1. `allowed_signers` file missing or incorrect
2. Signature file missing
3. Manifest was modified after signing
4. Key not in allowed_signers

**Solutions:**
```bash
# Check if allowed_signers exists
ls -la .github/allowed_signers

# Verify signature manually
ssh-keygen -Y verify \
  -f .github/allowed_signers \
  -I release@helixprojectai.com \
  -n file \
  -s releases/HGL-v1.2-beta.1/SHA256SUMS.txt.sig \
  < releases/HGL-v1.2-beta.1/SHA256SUMS.txt

# Re-sign if you have the private key
./tools/generate-hashes.sh releases/HGL-v1.2-beta.1 --sign
```

---

### Issue: Policy gate fails

**Symptoms:**
```
✗ Gate 3 (Transparency) - FAIL
```

**Causes:**
1. Release doesn't meet policy requirements
2. Policy definition changed
3. Bug in policy evaluation

**Solutions:**
```bash
# Run verification with verbose output
./tools/verify_and_eval.sh releases/HGL-v1.2-beta.1 --verbose

# Check policy definition
cat src/policy/gates.md

# Review provenance to see what failed
cat releases/HGL-v1.2-beta.1/provenance.json | jq '.policy'

# If this is expected, you can skip policy checks
./tools/verify_and_eval.sh releases/HGL-v1.2-beta.1 --skip-policy
```

---

### Issue: CI/CD workflow fails

**Symptoms:**
- GitHub Actions shows red X
- Workflow error in Actions tab

**Solutions:**
```bash
# 1. Check workflow logs in GitHub Actions tab

# 2. Run verification locally
./tools/verify_and_eval.sh releases/HGL-v1.2-beta.1

# 3. Check if workflows are up to date
git pull origin main
ls -la .github/workflows/

# 4. Manually trigger workflow
# Go to GitHub Actions → Select workflow → Run workflow

# 5. Check for required secrets
# GitHub repo → Settings → Secrets → Actions
```

---

### Issue: Pre-commit hook fails

**Symptoms:**
```
✗ Failed to regenerate manifest
```

**Causes:**
1. Tools not executable
2. Missing dependencies
3. Invalid release structure

**Solutions:**
```bash
# Check tool permissions
ls -la tools/generate-hashes.sh

# Make tools executable
chmod +x tools/generate-hashes.sh
chmod +x tools/generate_provenance.py

# Test tools manually
./tools/generate-hashes.sh releases/HGL-v1.2-beta.1

# Bypass hook if needed (emergency only)
git commit --no-verify
```

---

## Best Practices

### 1. Release Management

✅ **DO:**
- Generate provenance for every release
- Sign all hash manifests
- Use semantic versioning (v1.2.3)
- Tag releases in Git
- Keep release directories self-contained

❌ **DON'T:**
- Modify files after signing
- Reuse version numbers
- Skip verification steps
- Store secrets in repository

### 2. Key Management

✅ **DO:**
- Rotate keys annually
- Use hardware tokens for production keys
- Keep private keys secure (never commit!)
- Document key rotation in allowed_signers
- Use separate keys for different purposes

❌ **DON'T:**
- Share private keys
- Use weak passphrases
- Skip key expiration dates
- Store keys in cloud storage

### 3. CI/CD

✅ **DO:**
- Run full verification on every PR
- Use workflow dispatch for manual testing
- Monitor workflow failures
- Keep workflows up to date
- Test locally before pushing

❌ **DON'T:**
- Disable required checks
- Merge without CI passing
- Ignore test failures
- Modify workflows without testing

### 4. Documentation

✅ **DO:**
- Keep docs in sync with code
- Document breaking changes
- Provide examples
- Update changelog
- Link to relevant issues

❌ **DON'T:**
- Leave outdated docs
- Skip example updates
- Forget to version docs
- Hide known limitations

---

## FAQ

### Q: Do I need to install anything to verify releases?

**A:** No external dependencies for basic verification:
- **Linux/macOS:** Built-in `bash`, `sha256sum`/`shasum`, `ssh-keygen`
- **Windows:** Built-in PowerShell 5.1+

### Q: Can I verify releases offline?

**A:** Yes, if you have:
1. The release package
2. The `allowed_signers` file
3. Verification scripts

All cryptographic operations work offline.

### Q: How long do signatures remain valid?

**A:** Signatures themselves don't expire, but signing keys have validity periods defined in `allowed_signers`. Default: 1 year.

### Q: Can I use my own signing keys?

**A:** Yes! Generate an ED25519 key and add it to `allowed_signers`:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/my_key
# Add public key to .github/allowed_signers
```

### Q: What if I find a security issue?

**A:** Email: security@helixprojectai.com (PGP key available on website)

### Q: How do I contribute?

**A:**
1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a PR
5. CI/CD will verify your changes

### Q: Can I use this for my own project?

**A:** Yes! The infrastructure is Apache-2.0 licensed. See `LICENSE` file.

---

## Support

- **Documentation:** [https://github.com/helixprojectai/HGL/tree/main/docs](https://github.com/helixprojectai/HGL/tree/main/docs)
- **Issues:** [https://github.com/helixprojectai/HGL/issues](https://github.com/helixprojectai/HGL/issues)
- **Discussions:** [https://github.com/helixprojectai/HGL/discussions](https://github.com/helixprojectai/HGL/discussions)
- **Email:** support@helixprojectai.com

---

**Last Updated:** October 2025  
**Version:** 1.0
