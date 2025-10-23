# HGL v1.2-beta.1 Deployment Checklist

**Version:** 1.0  
**Estimated Time:** 2-4 hours  
**Difficulty:** Intermediate  
**Risk Level:** LOW

---

## Overview

This checklist guides you through deploying the HGL v1.2-beta.1 verification infrastructure to your repository. Follow each step in order.

**Prerequisites:**
- Git repository access (push rights)
- Basic command line knowledge
- SSH key generation ability (for signing)

---

## Phase 0: Preparation (15 minutes)

### 0.1 Review Documentation

- [ ] Read `HGL_GAP_ANALYSIS.md` completely
- [ ] Skim `IMPLEMENTATION_README.md` for familiarization
- [ ] Review `PACKAGE_INDEX.md` for file locations
- [ ] Understand current vs. target state

**Time Check:** 10 minutes

---

### 0.2 Backup Current Repository
```bash
# Clone current state
git clone https://github.com/helixprojectai-code/HELIX-GLYPH-LANGUAGE-HGL- \
  backup-$(date +%Y%m%d)

# Verify backup
cd backup-$(date +%Y%m%d)
git log --oneline -n 5
cd ..
```

- [ ] Backup created successfully
- [ ] Backup location noted: `__________________`

**Time Check:** 5 minutes

---

### 0.3 Create Deployment Branch
```bash
# Navigate to repository
cd HELIX-GLYPH-LANGUAGE-HGL-

# Create branch
git checkout -b deploy/v1.2-beta.1-infrastructure

# Verify branch
git branch
```

- [ ] Deployment branch created
- [ ] Currently on deployment branch

**Expected Output:**
```
* deploy/v1.2-beta.1-infrastructure
  main
```

**Time Check:** Total Phase 0 = 15 minutes

---

## Phase 1: File Installation (30 minutes)

### 1.1 Create Directory Structure
```bash
# Create required directories
mkdir -p tools
mkdir -p .github/workflows
mkdir -p .github
mkdir -p docs
```

- [ ] `tools/` directory exists
- [ ] `.github/workflows/` directory exists
- [ ] `docs/` directory exists

**Time Check:** 2 minutes

---

### 1.2 Install Verification Scripts
```bash
# Copy scripts (adjust paths to where you extracted the package)
cp path/to/hgl-implementation/verify_and_eval.sh tools/
cp path/to/hgl-implementation/verify_and_eval.ps1 tools/

# Set permissions
chmod +x tools/verify_and_eval.sh
chmod +x tools/verify_and_eval.ps1

# Verify
ls -la tools/verify_and_eval.*
```

- [ ] `tools/verify_and_eval.sh` exists and is executable
- [ ] `tools/verify_and_eval.ps1` exists and is executable

**Expected Output:**
```
-rwxr-xr-x  verify_and_eval.sh
-rwxr-xr-x  verify_and_eval.ps1
```

**Time Check:** 3 minutes

---

### 1.3 Install CI/CD Workflows
```bash
# Copy workflows
cp path/to/hgl-implementation/.github/workflows/*.yml .github/workflows/

# Verify
ls -la .github/workflows/
```

- [ ] `verify_provenance.yml` exists
- [ ] `verify_signatures.yml` exists
- [ ] `verify_policy.yml` exists
- [ ] `reproducibility_smoke.yml` exists

**Expected Output:**
```
verify_provenance.yml
verify_signatures.yml
verify_policy.yml
reproducibility_smoke.yml
```

**Time Check:** 3 minutes

---

### 1.4 Install Tools
```bash
# Copy tools
cp path/to/hgl-implementation/tools/generate_provenance.py tools/
cp path/to/hgl-implementation/tools/generate-hashes.sh tools/
cp path/to/hgl-implementation/tools/pre-commit-hook tools/

# Set permissions
chmod +x tools/generate-hashes.sh
chmod +x tools/generate_provenance.py
chmod +x tools/pre-commit-hook

# Verify
ls -la tools/
```

- [ ] `tools/generate_provenance.py` exists and is executable
- [ ] `tools/generate-hashes.sh` exists and is executable
- [ ] `tools/pre-commit-hook` exists and is executable

**Time Check:** 3 minutes

---

### 1.5 Install Security Infrastructure
```bash
# Copy allowed_signers
cp path/to/hgl-implementation/.github/allowed_signers .github/

# Verify
ls -la .github/allowed_signers
```

- [ ] `.github/allowed_signers` exists

**⚠️ CRITICAL:** You MUST update this file with your actual public keys (see Phase 2)

**Time Check:** 2 minutes

---

### 1.6 Install Documentation
```bash
# Copy documentation
cp path/to/hgl-implementation/docs/*.md docs/

# Verify
ls -la docs/
```

- [ ] `docs/HGL_GAP_ANALYSIS.md` exists
- [ ] `docs/IMPLEMENTATION_README.md` exists
- [ ] `docs/DEPLOYMENT_CHECKLIST.md` exists
- [ ] `docs/PACKAGE_INDEX.md` exists

**Time Check:** 2 minutes

---

### 1.7 Verify File Structure
```bash
# Check complete structure
tree -L 2 tools/ .github/ docs/
```

**Expected Structure:**
```
tools/
├── generate_provenance.py
├── generate-hashes.sh
├── pre-commit-hook
├── verify_and_eval.sh
└── verify_and_eval.ps1

.github/
├── allowed_signers
└── workflows/
    ├── verify_provenance.yml
    ├── verify_signatures.yml
    ├── verify_policy.yml
    └── reproducibility_smoke.yml

docs/
├── HGL_GAP_ANALYSIS.md
├── IMPLEMENTATION_README.md
├── DEPLOYMENT_CHECKLIST.md
└── PACKAGE_INDEX.md
```

- [ ] File structure matches expected layout

**Time Check:** 2 minutes

---

### 1.8 Initial Commit
```bash
# Stage all new files
git add tools/ .github/ docs/

# Commit
git commit -m "Infrastructure: Add verification tooling and CI/CD workflows"

# Verify commit
git log --oneline -n 1
git diff --stat main..HEAD
```

- [ ] Files committed successfully
- [ ] Commit message is descriptive

**Time Check:** 3 minutes

---

**Total Phase 1:** 20 minutes (padded to 30 for first-time deployment)

---

## Phase 2: Configuration (30 minutes)

### 2.1 Generate Signing Key
```bash
# Generate ED25519 key
ssh-keygen -t ed25519 \
  -f ~/.ssh/hgl_release_key \
  -C "release@helixprojectai.com"

# When prompted:
# - Enter a strong passphrase
# - Confirm passphrase
```

- [ ] Private key created: `~/.ssh/hgl_release_key`
- [ ] Public key created: `~/.ssh/hgl_release_key.pub`
- [ ] Passphrase documented in secure location

**⚠️ SECURITY:**
- NEVER commit the private key
- Store passphrase in password manager
- Consider using hardware token for production

**Time Check:** 5 minutes

---

### 2.2 Update allowed_signers File
```bash
# Display your public key
cat ~/.ssh/hgl_release_key.pub

# Edit allowed_signers
nano .github/allowed_signers
```

**Replace placeholder entries with:**
```
release@helixprojectai.com namespaces="file" valid-after="20250101" valid-before="20260101" ssh-ed25519 AAAA[your-actual-public-key]
```

**Format:**
```
<email> namespaces="<namespaces>" valid-after="<YYYYMMDD>" valid-before="<YYYYMMDD>" <key-type> <key-data>
```

- [ ] Placeholder keys removed
- [ ] Your public key added
- [ ] Valid-after date is correct (today or earlier)
- [ ] Valid-before date is ~1 year in future
- [ ] File saved

**Time Check:** 10 minutes

---

### 2.3 Configure Git Hooks
```bash
# Install pre-commit hook
cp tools/pre-commit-hook .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Verify
ls -la .git/hooks/pre-commit
```

- [ ] Pre-commit hook installed
- [ ] Hook is executable

**Expected Output:**
```
-rwxr-xr-x  .git/hooks/pre-commit
```

**Time Check:** 2 minutes

---

### 2.4 Commit Configuration
```bash
# Stage changes
git add .github/allowed_signers

# Commit
git commit -m "Security: Add release signing public key"

# Push to remote
git push origin deploy/v1.2-beta.1-infrastructure
```

- [ ] Configuration committed
- [ ] Changes pushed to remote

**Time Check:** 3 minutes

---

### 2.5 Set Up GitHub Secrets (Optional)

If using GitHub Actions with signature verification:

1. Go to GitHub repository → Settings → Secrets → Actions
2. Add secret: `HGL_RELEASE_PUBLIC_KEY`
   - Value: Content of `~/.ssh/hgl_release_key.pub`

- [ ] GitHub secret configured (if using Actions)
- [ ] Secret name documented: `HGL_RELEASE_PUBLIC_KEY`

**Time Check:** 5 minutes

---

### 2.6 Test Configuration
```bash
# Test hash generation
./tools/generate-hashes.sh releases/HGL-v1.2-beta.1

# Test signing
./tools/generate-hashes.sh releases/HGL-v1.2-beta.1 --sign

# Verify signature
ssh-keygen -Y verify \
  -f .github/allowed_signers \
  -I release@helixprojectai.com \
  -n file \
  -s releases/HGL-v1.2-beta.1/SHA256SUMS.txt.sig \
  < releases/HGL-v1.2-beta.1/SHA256SUMS.txt
```

- [ ] Hash generation successful
- [ ] Signing successful
- [ ] Signature verification successful

**Expected Output:**
```
Good "file" signature for release@helixprojectai.com with ED25519 key SHA256:...
```

**Time Check:** 5 minutes

---

**Total Phase 2:** 30 minutes

---

## Phase 3: Testing (1-2 hours)

### 3.1 Test Verification Scripts

#### Test 1: Bash Verification
```bash
./tools/verify_and_eval.sh releases/HGL-v1.2-beta.1
```

- [ ] Hash verification: PASS
- [ ] Signature verification: PASS
- [ ] Policy evaluation: PASS (or expected result)
- [ ] Exit code: 0

**Expected Output:**
```
✓ SHA256 hashes verified
✓ Signature verified
✓ Policy evaluation complete
All checks passed ✓
```

**Time Check:** 5 minutes

---

#### Test 2: PowerShell Verification (Windows or WSL)
```powershell
.\tools\verify_and_eval.ps1 -ReleaseDir "releases\HGL-v1.2-beta.1"
```

- [ ] Hash verification: PASS
- [ ] Signature verification: PASS
- [ ] Policy evaluation: PASS (or expected result)
- [ ] Exit code: 0

**Time Check:** 5 minutes

---

### 3.2 Test Provenance Generation
```bash
# Generate provenance for existing release
python tools/generate_provenance.py \
  --version 1.2-beta.1 \
  --release-dir releases/HGL-v1.2-beta.1

# Verify JSON is valid
cat releases/HGL-v1.2-beta.1/provenance.json | jq .

# Check key fields
cat releases/HGL-v1.2-beta.1/provenance.json | jq '{
  artifact,
  git: .git.commit,
  inputs: (.inputs | length),
  outputs: (.outputs | length),
  policy: .policy.status
}'
```

- [ ] Provenance generated successfully
- [ ] JSON is valid
- [ ] Git commit captured
- [ ] Input/output files counted
- [ ] Policy status recorded

**Expected Output:**
```json
{
  "artifact": "HGL v1.2-beta.1",
  "git": "abc123...",
  "inputs": 15,
  "outputs": 8,
  "policy": "pass"
}
```

**Time Check:** 10 minutes

---

### 3.3 Test Pre-commit Hook
```bash
# Make a trivial change to a release file
echo "# Test" >> releases/HGL-v1.2-beta.1/README.md

# Stage and commit
git add releases/HGL-v1.2-beta.1/README.md
git commit -m "Test: Pre-commit hook"

# Verify hook ran
git log --oneline -n 1
git diff HEAD^ HEAD --stat
```

- [ ] Pre-commit hook executed
- [ ] Manifests regenerated automatically
- [ ] Updated manifests staged for commit

**Expected Output:**
```
▶ Pre-commit hook: Checking 1 release(s)
▶ Processing: releases/HGL-v1.2-beta.1
✓ Manifest updated
✓ Pre-commit checks complete
```

**Time Check:** 10 minutes

---

### 3.4 Test CI/CD Workflows Locally

#### Test Provenance Workflow
```bash
# Install act (GitHub Actions local runner)
# macOS: brew install act
# Linux: See https://github.com/nektos/act

# Run provenance workflow
act push -W .github/workflows/verify_provenance.yml
```

- [ ] Workflow syntax valid
- [ ] Provenance validation passes
- [ ] No errors in logs

**Time Check:** 15 minutes

---

#### Test Signature Workflow
```bash
act push -W .github/workflows/verify_signatures.yml
```

- [ ] Workflow syntax valid
- [ ] Signature validation passes
- [ ] No errors in logs

**Time Check:** 15 minutes

---

#### Test Policy Workflow
```bash
act push -W .github/workflows/verify_policy.yml
```

- [ ] Workflow syntax valid
- [ ] All 8 test vectors pass
- [ ] Matrix strategy works correctly
- [ ] No errors in logs

**Time Check:** 20 minutes

---

### 3.5 Test on GitHub (Push to Remote)
```bash
# Push deployment branch
git push origin deploy/v1.2-beta.1-infrastructure

# Monitor GitHub Actions
# Go to: https://github.com/your-repo/actions
```

- [ ] All workflows triggered automatically
- [ ] `verify_provenance.yml`: PASS
- [ ] `verify_signatures.yml`: PASS
- [ ] `verify_policy.yml`: PASS
- [ ] No workflow failures

**Time Check:** 10 minutes

---

### 3.6 Create Test Release
```bash
# Create a test release
mkdir -p releases/HGL-v1.2-beta.2-test
echo "Test release" > releases/HGL-v1.2-beta.2-test/README.md

# Generate manifests
python tools/generate_provenance.py \
  --version 1.2-beta.2-test \
  --release-dir releases/HGL-v1.2-beta.2-test

./tools/generate-hashes.sh releases/HGL-v1.2-beta.2-test --sign

# Verify
./tools/verify_and_eval.sh releases/HGL-v1.2-beta.2-test

# Commit
git add releases/HGL-v1.2-beta.2-test
git commit -m "Test: Create test release"
git push origin deploy/v1.2-beta.1-infrastructure
```

- [ ] Test release created successfully
- [ ] Provenance generated
- [ ] Hashes signed
- [ ] Verification passes
- [ ] CI/CD runs and passes

**Time Check:** 15 minutes

---

**Total Phase 3:** 1 hour 45 minutes (can take up to 2 hours for thorough testing)

---

## Phase 4: Go Live (30 minutes)

### 4.1 Create Pull Request

1. Go to GitHub repository
2. Navigate to Pull Requests
3. Click "New Pull Request"
4. Base: `main`, Compare: `deploy/v1.2-beta.1-infrastructure`
5. Fill in PR template:
```markdown
## Description
Deploy HGL v1.2-beta.1 verification infrastructure

## Changes
- Add cross-platform verification scripts (Bash + PowerShell)
- Add CI/CD workflows (4 workflows)
- Add provenance/hash generation tools
- Add signing infrastructure
- Add comprehensive documentation

## Testing
- [x] All verification scripts tested
- [x] CI/CD workflows passing
- [x] Documentation reviewed
- [x] Test release created and verified

## Checklist
- [x] DEPLOYMENT_CHECKLIST.md followed completely
- [x] All tests passing
- [x] Documentation complete
- [x] Signing keys configured
```

- [ ] Pull request created
- [ ] PR number noted: `#____`
- [ ] All CI checks passing on PR

**Time Check:** 10 minutes

---

### 4.2 Code Review

**Recommended Reviewers:**
- Repository maintainer
- Security team member
- At least one developer

**Review Focus:**
- [ ] File locations correct
- [ ] No private keys committed
- [ ] Workflows configured properly
- [ ] Documentation accurate

**Time Check:** Variable (can be async)

---

### 4.3 Merge to Main

Once approved:
```bash
# Update local main
git checkout main
git pull origin main

# Merge deployment branch (GitHub will do this via UI, or:)
git merge --no-ff deploy/v1.2-beta.1-infrastructure

# Push
git push origin main
```

- [ ] PR approved by reviewers
- [ ] PR merged to main
- [ ] All CI checks passing on main
- [ ] Deployment branch deleted (cleanup)

**Time Check:** 5 minutes

---

### 4.4 Tag Release
```bash
# Create annotated tag
git tag -a infrastructure-v1.0 -m "HGL v1.2-beta.1 verification infrastructure"

# Push tag
git push origin infrastructure-v1.0

# Verify tag
git show infrastructure-v1.0
```

- [ ] Tag created
- [ ] Tag pushed to remote
- [ ] Tag visible on GitHub

**Time Check:** 5 minutes

---

### 4.5 Create GitHub Release

1. Go to GitHub → Releases → Draft a new release
2. Choose tag: `infrastructure-v1.0`
3. Release title: "HGL v1.2-beta.1 Infrastructure"
4. Description:
```markdown
## HGL v1.2-beta.1 Verification Infrastructure

Complete verification and CI/CD infrastructure for HGL releases.

### What's Included
- ✅ Cross-platform verification (Linux/macOS/Windows)
- ✅ Automated CI/CD pipelines
- ✅ Provenance generation
- ✅ SHA256 manifest generation with ED25519 signing
- ✅ Pre-commit automation
- ✅ Comprehensive documentation

### Quick Start
See [IMPLEMENTATION_README.md](docs/IMPLEMENTATION_README.md)

### Documentation
- [Gap Analysis](docs/HGL_GAP_ANALYSIS.md)
- [Usage Guide](docs/IMPLEMENTATION_README.md)
- [Deployment Checklist](docs/DEPLOYMENT_CHECKLIST.md)
- [File Reference](docs/PACKAGE_INDEX.md)
```

- [ ] Release created
- [ ] Release published
- [ ] Release URL noted: `_______________`

**Time Check:** 10 minutes

---

### 4.6 Announce Deployment

**Internal:**
- [ ] Notify team via Slack/email
- [ ] Update internal documentation
- [ ] Schedule team demo (optional)

**External:**
- [ ] Update README.md with verification instructions
- [ ] Post to project blog/website
- [ ] Notify users via newsletter

**Template Email:**
```
Subject: HGL v1.2-beta.1 Infrastructure Deployed ✅

Team,

We've successfully deployed the HGL v1.2-beta.1 verification infrastructure!

Key improvements:
- Windows users can now verify releases
- Automated CI/CD for all verification
- Cryptographic signing on all manifests

Documentation: [link]
Questions: Reply to this thread

Great work, team!
```

**Time Check:** 10 minutes (variable for external announcements)

---

**Total Phase 4:** 30-60 minutes

---

## Post-Deployment

### Monitoring (First Week)

- [ ] **Day 1:** Monitor CI/CD for failures
- [ ] **Day 2:** Check for user questions/issues
- [ ] **Day 3:** Review GitHub Actions usage metrics
- [ ] **Day 7:** Gather team feedback

### Documentation Updates

- [ ] Update main README.md with links to new docs
- [ ] Add "Verification" section to user guide
- [ ] Create FAQ based on questions received

### Future Enhancements

See `HGL_GAP_ANALYSIS.md` Section 5.2 for roadmap:
- [ ] SBOM generation
- [ ] Sigstore integration
- [ ] Web verification UI

---

## Rollback Procedure

If critical issues arise:

### Immediate Rollback (< 1 hour after deployment)
```bash
# Revert the merge commit
git checkout main
git pull
git revert HEAD -m 1
git push origin main
```

- [ ] Revert commit created
- [ ] Pushed to main
- [ ] CI/CD passing
- [ ] Team notified

---

### Full Rollback (> 1 hour after deployment)
```bash
# Restore from backup
cd backup-$(date +%Y%m%d)
git push origin main --force

# Warning: This overwrites history!
# Only use if absolutely necessary
```

- [ ] Backup restored
- [ ] Repository state confirmed
- [ ] Post-mortem scheduled

---

## Success Criteria

✅ **Deployment is successful if:**
- [ ] All files installed correctly
- [ ] Verification scripts work on all platforms
- [ ] CI/CD workflows passing
- [ ] Signing infrastructure operational
- [ ] Documentation accessible
- [ ] No critical bugs reported
- [ ] Team able to create new releases using new tooling

❌ **Rollback required if:**
- CI/CD workflows prevent merging PRs
- Verification scripts fail on valid releases
- Critical security issue discovered
- Breaking changes to existing workflows

---

## Completion

**Deployment Date:** `_______________`  
**Deployed By:** `_______________`  
**Total Time:** `_______________`  
**Issues Encountered:** `_______________`

---

**Congratulations!** 🎉

The HGL v1.2-beta.1 infrastructure is now deployed and operational.

**Next Steps:**
1. Monitor for issues (first week)
2. Create your next release using the new tooling
3. Gather team feedback
4. Plan future enhancements

---

**Document End**
