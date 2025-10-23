# HGL Server Operations Guide

Day-to-day operational procedures for HGL verification infrastructure.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Release Management](#release-management)
3. [Verification Workflows](#verification-workflows)
4. [Monitoring](#monitoring)
5. [Maintenance](#maintenance)
6. [Incident Response](#incident-response)

---

## Daily Operations

### Checking Server Health
```bash
# Check disk space
df -h /opt/helix

# Check system resources
free -h
uptime

# Check Git status
cd ~/git/hgl
git status
git fetch origin
git log --oneline -5
```

### Pulling Latest Changes
```bash
# Navigate to repo
cd ~/git/hgl

# Check current branch
git branch

# Pull latest from main
git pull origin main

# Check for script updates
ls -la tools/
```

### Verifying Configuration
```bash
# Check allowed_signers is valid
cat .github/allowed_signers

# Verify signing key exists
ls -la ~/.ssh/hgl_release_key*

# Test signing works
./tools/generate-hashes.sh /tmp --sign
```

---

## Release Management

### Creating a New Release

#### Step 1: Prepare Release Directory
```bash
# Create release directory
RELEASE_VERSION="HGL-v1.2-beta.1"
mkdir -p releases/$RELEASE_VERSION

# Copy release artifacts
cp build/output/* releases/$RELEASE_VERSION/

# Add release metadata
cat > releases/$RELEASE_VERSION/RELEASE_NOTES.md << EOF
# $RELEASE_VERSION

**Release Date:** $(date +%Y-%m-%d)
**Released By:** $USER

## Changes
- Feature 1
- Feature 2
- Bug fix 1

## Installation
See [README.md](README.md) for installation instructions.
EOF
```

#### Step 2: Generate Hashes
```bash
# Generate SHA256 hashes with signature
./tools/generate-hashes.sh releases/$RELEASE_VERSION --sign

# Verify files created
ls -la releases/$RELEASE_VERSION/
# Should see:
# - SHA256SUMS.txt
# - SHA256SUMS.txt.sig
```

#### Step 3: Generate Provenance
```bash
# Generate provenance manifest
python3 tools/generate_provenance.py releases/$RELEASE_VERSION

# Verify provenance
cat releases/$RELEASE_VERSION/provenance.json
```

#### Step 4: Verify Release
```bash
# Run complete verification
./tools/verify_and_eval.sh releases/$RELEASE_VERSION

# Should see all checks pass
```

#### Step 5: Commit and Tag
```bash
# Stage release files
git add releases/$RELEASE_VERSION/

# Commit
git commit -m "Release: $RELEASE_VERSION

- Add release artifacts
- Generate signed manifest
- Add provenance metadata"

# Create annotated tag
git tag -a $RELEASE_VERSION -m "Release $RELEASE_VERSION"

# Push commit and tag
git push origin main
git push origin $RELEASE_VERSION
```

### Updating an Existing Release
```bash
# Never modify files in signed releases!
# Instead, create a new patch release

RELEASE_VERSION="HGL-v1.2-beta.2"  # Increment version
mkdir -p releases/$RELEASE_VERSION

# Copy and update files
# Regenerate manifest
./tools/generate-hashes.sh releases/$RELEASE_VERSION --sign
```

### Verifying a Release
```bash
# Verify hash integrity
cd releases/HGL-v1.2-beta.1
sha256sum -c SHA256SUMS.txt

# Verify signature
ssh-keygen -Y verify \
  -f ../../.github/allowed_signers \
  -I release@helixprojectai.com \
  -n file \
  -s SHA256SUMS.txt.sig \
  < SHA256SUMS.txt

# Run full verification
cd ../..
./tools/verify_and_eval.sh releases/HGL-v1.2-beta.1
```

---

## Verification Workflows

### Quick Verification
```bash
# Verify hashes only
cd releases/HGL-vX.Y.Z
sha256sum -c SHA256SUMS.txt
```

### Full Verification
```bash
# Run complete verification script
./tools/verify_and_eval.sh releases/HGL-vX.Y.Z

# Checks performed:
# ✓ Directory exists
# ✓ SHA256SUMS.txt present
# ✓ All files have hashes
# ✓ Hashes match actual files
# ✓ Signature present
# ✓ Signature valid
# ✓ Provenance present
# ✓ Provenance valid
```

### Signature-Only Verification
```bash
# Verify just the signature
ssh-keygen -Y verify \
  -f .github/allowed_signers \
  -I release@helixprojectai.com \
  -n file \
  -s releases/HGL-vX.Y.Z/SHA256SUMS.txt.sig \
  < releases/HGL-vX.Y.Z/SHA256SUMS.txt
```

### Batch Verification
```bash
# Verify all releases
for release in releases/HGL-*; do
  echo "Verifying $release..."
  ./tools/verify_and_eval.sh "$release"
done
```

---

## Monitoring

### Log Locations
```bash
# Git operations log
cat ~/.gitconfig

# SSH operations
sudo journalctl -u ssh -f

# System logs
sudo tail -f /var/log/syslog
```

### Monitoring Script

Create a monitoring script:
```bash
cat > ~/monitor_hgl.sh << 'EOF'
#!/usr/bin/env bash
# HGL Infrastructure Monitoring

echo "=== HGL Server Status ==="
echo "Timestamp: $(date)"
echo

# Disk space
echo "Disk Space:"
df -h ~/git/hgl | tail -1

# Git status
cd ~/git/hgl
echo
echo "Git Status:"
echo "  Branch: $(git branch --show-current)"
echo "  Latest commit: $(git log --oneline -1)"
echo "  Behind origin: $(git rev-list HEAD..origin/main --count) commits"

# Key status
echo
echo "Signing Key:"
if [ -f ~/.ssh/hgl_release_key ]; then
  echo "  ✓ Present"
  echo "  Fingerprint: $(ssh-keygen -lf ~/.ssh/hgl_release_key.pub | awk '{print $2}')"
else
  echo "  ✗ Missing!"
fi

# Test signing
echo
echo "Test Signing:"
if ./tools/generate-hashes.sh /tmp --sign &>/dev/null; then
  echo "  ✓ Working"
else
  echo "  ✗ Failed!"
fi

echo
echo "=== End Status ==="
EOF

chmod +x ~/monitor_hgl.sh
```

Run monitoring:
```bash
# Run once
~/monitor_hgl.sh

# Run in cron (every hour)
(crontab -l 2>/dev/null; echo "0 * * * * ~/monitor_hgl.sh >> ~/hgl_monitor.log 2>&1") | crontab -
```

### Alerting

Set up email alerts for failures:
```bash
cat > ~/check_hgl.sh << 'EOF'
#!/usr/bin/env bash
# Check HGL and send alert on failure

cd ~/git/hgl

if ! ./tools/generate-hashes.sh /tmp --sign &>/dev/null; then
  echo "HGL signing failed on $(hostname) at $(date)" | \
    mail -s "ALERT: HGL Signing Failure" admin@example.com
fi
EOF

chmod +x ~/check_hgl.sh

# Run every 6 hours
(crontab -l 2>/dev/null; echo "0 */6 * * * ~/check_hgl.sh") | crontab -
```

---

## Maintenance

### Updating Dependencies
```bash
# Update package lists
sudo apt update

# Upgrade packages
sudo apt upgrade -y

# Check for new versions
git --version
python3 --version
ssh -V
jq --version
```

### Cleaning Old Files
```bash
# Remove old test files
rm -rf /tmp/test-* /tmp/final-test /tmp/manual-test

# Clean Git repo
cd ~/git/hgl
git gc
git prune

# Remove old backups (older than 90 days)
find ~/.ssh/*.backup -mtime +90 -delete
```

### Rotating Keys

Plan key rotation annually:
```bash
# 1. Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/hgl_release_key_2026 -C "release@helixprojectai.com"

# 2. Test new key
export SSH_KEY=~/.ssh/hgl_release_key_2026
./tools/generate-hashes.sh /tmp --sign

# 3. Add new key to allowed_signers (keep old key for verification)
cat >> .github/allowed_signers << EOF

# Production Key 2026
release@helixprojectai.com $(ssh-keygen -y -f ~/.ssh/hgl_release_key_2026 | awk '{print $1, $2}')
EOF

# 4. Commit and push
git add .github/allowed_signers
git commit -m "Security: Add 2026 signing key"
git push origin main

# 5. Switch to new key
mv ~/.ssh/hgl_release_key ~/.ssh/hgl_release_key_2025_retired
mv ~/.ssh/hgl_release_key_2026 ~/.ssh/hgl_release_key
```

### Backup Procedures
```bash
# Backup private key (encrypted)
tar czf - ~/.ssh/hgl_release_key | \
  gpg --symmetric --cipher-algo AES256 > \
  ~/backups/hgl_key_$(date +%Y%m%d).tar.gz.gpg

# Backup repository
cd ~/git
tar czf hgl_backup_$(date +%Y%m%d).tar.gz hgl/

# Backup to remote (if available)
scp ~/backups/hgl_key_$(date +%Y%m%d).tar.gz.gpg backup-server:~/backups/
```

---

## Incident Response

### Compromised Key

If you suspect the signing key has been compromised:
```bash
# 1. IMMEDIATELY generate new key
ssh-keygen -t ed25519 -f ~/.ssh/hgl_release_key_emergency -C "release@helixprojectai.com"

# 2. Remove old key from allowed_signers
nano .github/allowed_signers
# Comment out or remove the compromised key line

# 3. Add new key
cat >> .github/allowed_signers << EOF
# Emergency replacement key $(date +%Y-%m-%d)
release@helixprojectai.com $(ssh-keygen -y -f ~/.ssh/hgl_release_key_emergency | awk '{print $1, $2}')
EOF

# 4. Commit immediately
git add .github/allowed_signers
git commit -m "SECURITY: Revoke compromised key, add emergency key"
git push origin main

# 5. Notify team
# 6. Review all releases signed with old key
# 7. Consider re-signing recent releases with new key
```

### Verification Failures

If verification starts failing:
```bash
# 1. Check if key changed
ssh-keygen -lf ~/.ssh/hgl_release_key.pub

# 2. Verify allowed_signers has correct key
cat .github/allowed_signers

# 3. Test with known-good release
./tools/verify_and_eval.sh releases/HGL-v1.0.0

# 4. Check OpenSSH version
ssh -V

# 5. Review recent commits
git log --oneline -10

# 6. Check for file corruption
sha256sum .github/allowed_signers
sha256sum tools/verify_and_eval.sh
```

### Server Failure Recovery

If server fails and needs rebuild:
```bash
# 1. Clone repository on new server
cd ~/git
git clone git@github.com:stephenh67/HELIX-GLYPH-LANGUAGE-HGL-.git hgl

# 2. Restore private key from backup
gpg --decrypt ~/backups/hgl_key_YYYYMMDD.tar.gz.gpg | tar xz -C ~

# 3. Verify key
ls -la ~/.ssh/hgl_release_key*
ssh-keygen -lf ~/.ssh/hgl_release_key.pub

# 4. Install dependencies
sudo apt install tree git python3 python3-pip openssh-client jq build-essential python3-jsonschema python3-yaml

# 5. Test signing
cd ~/git/hgl
./tools/generate-hashes.sh /tmp --sign

# 6. Verify against production releases
./tools/verify_and_eval.sh releases/HGL-v1.2-beta.1
```

---

## Common Tasks Quick Reference

### Sign a Release
```bash
./tools/generate-hashes.sh releases/HGL-vX.Y.Z --sign
```

### Verify a Release
```bash
./tools/verify_and_eval.sh releases/HGL-vX.Y.Z
```

### Generate Provenance
```bash
python3 tools/generate_provenance.py releases/HGL-vX.Y.Z
```

### Check Key Fingerprint
```bash
ssh-keygen -lf ~/.ssh/hgl_release_key.pub
```

### Pull Latest Changes
```bash
git pull origin main
```

### Test Everything
```bash
./tools/generate-hashes.sh /tmp/test --sign && \
./tools/verify_and_eval.sh /tmp/test && \
echo "✓ All systems operational"
```

---

## Support

- **Deployment Guide:** [SERVER_DEPLOYMENT_GUIDE.md](SERVER_DEPLOYMENT_GUIDE.md)
- **Troubleshooting:** [SERVER_TROUBLESHOOTING.md](SERVER_TROUBLESHOOTING.md)
- **Security:** [SERVER_SECURITY_HARDENING.md](SERVER_SECURITY_HARDENING.md)
- **Quick Reference:** [SERVER_QUICK_REFERENCE.md](SERVER_QUICK_REFERENCE.md)

---

**Last Updated:** 2025-10-23  
**Version:** 1.0.0  
**Maintained By:** HGL Infrastructure Team
