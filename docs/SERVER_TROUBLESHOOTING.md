# HGL Server Troubleshooting Guide

Common issues and solutions for HGL server infrastructure.

## Table of Contents

1. [Diagnostic Tools](#diagnostic-tools)
2. [Git Issues](#git-issues)
3. [SSH Issues](#ssh-issues)
4. [Signing Issues](#signing-issues)
5. [Verification Issues](#verification-issues)
6. [Permission Issues](#permission-issues)
7. [Performance Issues](#performance-issues)

---

## Diagnostic Tools

### System Information
```bash
# System details
uname -a
lsb_release -a
cat /etc/os-release

# Resource usage
free -h
df -h
top -bn1 | head -20

# Network
ip addr show
ip route show
```

### HGL-Specific Diagnostics
```bash
cat > ~/diagnose_hgl.sh << 'EOF'
#!/usr/bin/env bash
# HGL Diagnostic Script

echo "=== HGL Diagnostics ==="
echo "Timestamp: $(date)"
echo

# System
echo "=== System ==="
echo "OS: $(lsb_release -ds)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo

# Dependencies
echo "=== Dependencies ==="
echo "Git: $(git --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "Python: $(python3 --version 2>/dev/null || echo 'NOT INSTALLED')"
echo "OpenSSH: $(ssh -V 2>&1 | head -1 || echo 'NOT INSTALLED')"
echo "jq: $(jq --version 2>/dev/null || echo 'NOT INSTALLED')"
echo

# Repository
echo "=== Repository ==="
if [ -d ~/git/hgl/.git ]; then
  cd ~/git/hgl
  echo "Location: $(pwd)"
  echo "Branch: $(git branch --show-current)"
  echo "Latest commit: $(git log --oneline -1)"
  echo "Status: $(git status --short | wc -l) files changed"
  echo "Remote: $(git remote get-url origin)"
else
  echo "Repository NOT FOUND at ~/git/hgl"
fi
echo

# Keys
echo "=== SSH Keys ==="
if [ -f ~/.ssh/hgl_release_key ]; then
  echo "✓ Private key present"
  echo "  Location: ~/.ssh/hgl_release_key"
  echo "  Permissions: $(stat -c %a ~/.ssh/hgl_release_key)"
  echo "  Fingerprint: $(ssh-keygen -lf ~/.ssh/hgl_release_key.pub | awk '{print $2}')"
else
  echo "✗ Private key MISSING"
fi
echo

# Configuration
echo "=== Configuration ==="
if [ -f ~/git/hgl/.github/allowed_signers ]; then
  echo "✓ allowed_signers present"
  echo "  Keys configured: $(grep -c "^[^#]" ~/git/hgl/.github/allowed_signers)"
else
  echo "✗ allowed_signers MISSING"
fi
echo

# Test signing
echo "=== Test Signing ==="
cd ~/git/hgl 2>/dev/null
if ./tools/generate-hashes.sh /tmp/diagnostic-test --sign &>/dev/null; then
  echo "✓ Signing works"
  rm -rf /tmp/diagnostic-test
else
  echo "✗ Signing FAILED"
fi

echo
echo "=== End Diagnostics ==="
EOF

chmod +x ~/diagnose_hgl.sh
~/diagnose_hgl.sh
```

---

## Git Issues

### Issue: "Permission denied (publickey)"

**Symptoms:**
```
git@github.com: Permission denied (publickey).
fatal: Could not read from remote repository.
```

**Diagnosis:**
```bash
# Test SSH connection
ssh -T git@github.com

# Check SSH keys
ls -la ~/.ssh/
```

**Solution:**
```bash
# Generate new SSH key
ssh-keygen -t ed25519 -C "your.email@example.com"

# Display public key
cat ~/.ssh/id_ed25519.pub

# Add to GitHub: https://github.com/settings/keys

# Add key to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Test connection
ssh -T git@github.com
```

### Issue: "fatal: not a git repository"

**Symptoms:**
```
fatal: not a git repository (or any of the parent directories): .git
```

**Diagnosis:**
```bash
# Check current directory
pwd

# Look for .git directory
ls -la .git
```

**Solution:**
```bash
# Navigate to correct directory
cd ~/git/hgl

# Or clone if missing
cd ~/git
git clone git@github.com:stephenh67/HELIX-GLYPH-LANGUAGE-HGL-.git hgl
```

### Issue: "Your branch is behind"

**Symptoms:**
```
Your branch is behind 'origin/main' by 5 commits.
```

**Solution:**
```bash
# Pull latest changes
git pull origin main

# If there are local changes, stash first
git stash
git pull origin main
git stash pop
```

### Issue: Merge Conflicts

**Symptoms:**
```
CONFLICT (content): Merge conflict in file.txt
Automatic merge failed; fix conflicts and then commit the result.
```

**Solution:**
```bash
# View conflicts
git status

# Edit conflicted files manually
nano <conflicted-file>

# Mark as resolved
git add <conflicted-file>

# Complete merge
git commit

# Or abort merge
git merge --abort
```

---

## SSH Issues

### Issue: SSH Connection Times Out

**Diagnosis:**
```bash
# Test connection with verbose output
ssh -vvv git@github.com

# Check network
ping github.com

# Check firewall
sudo ufw status
```

**Solution:**
```bash
# Allow outbound SSH
sudo ufw allow out 22/tcp

# Try HTTPS instead
git remote set-url origin https://github.com/username/repo.git
```

### Issue: "Too many authentication failures"

**Symptoms:**
```
Received disconnect from host: 2: Too many authentication failures
```

**Diagnosis:**
```bash
# Check how many keys are loaded
ssh-add -l
```

**Solution:**
```bash
# Clear all keys
ssh-add -D

# Add only needed key
ssh-add ~/.ssh/id_ed25519

# Or specify key in ssh config
cat >> ~/.ssh/config << EOF
Host github.com
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF
```

### Issue: SSH Key Permissions Wrong

**Symptoms:**
```
Permissions 0644 for '/home/user/.ssh/id_ed25519' are too open.
```

**Solution:**
```bash
# Fix permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 644 ~/.ssh/known_hosts
chmod 600 ~/.ssh/config

# Verify
ls -la ~/.ssh/
```

---

## Signing Issues

### Issue: "Could not load key"

**Symptoms:**
```
Could not load key "/home/user/.ssh/hgl_release_key": invalid format
```

**Diagnosis:**
```bash
# Check key format
file ~/.ssh/hgl_release_key

# Try to read key
ssh-keygen -y -f ~/.ssh/hgl_release_key
```

**Solution:**
```bash
# If corrupted, restore from backup
cp ~/.ssh/hgl_release_key.backup ~/.ssh/hgl_release_key

# Or regenerate
ssh-keygen -t ed25519 -f ~/.ssh/hgl_release_key -C "release@helixprojectai.com"

# Update allowed_signers with new key
```

### Issue: Passphrase Prompt Hangs

**Symptoms:**
Script hangs at signing step with no prompt visible.

**Diagnosis:**
```bash
# Check if key has passphrase
ssh-keygen -y -f ~/.ssh/hgl_release_key
# Will prompt for passphrase if set
```

**Solution:**
```bash
# Use ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/hgl_release_key

# Or regenerate without passphrase (less secure)
ssh-keygen -t ed25519 -f ~/.ssh/hgl_release_key -C "release@helixprojectai.com" -N ""
```

### Issue: "Signature file contains prompt text"

**Symptoms:**
```
Couldn't parse signature: missing header
```

**Diagnosis:**
```bash
# Check signature file content
cat /path/to/SHA256SUMS.txt.sig
```

**Solution:**
```bash
# The script has a bug - it redirects stdout
# Fix line 222 in tools/generate-hashes.sh
# Remove: > "$SIG_FILE"

sed -i '222s| > "$SIG_FILE"||' tools/generate-hashes.sh

# Add rm -f before signing
sed -i '222i\    rm -f "$SIG_FILE"' tools/generate-hashes.sh
```

### Issue: "Permission denied" when signing

**Diagnosis:**
```bash
# Check key permissions
ls -la ~/.ssh/hgl_release_key
```

**Solution:**
```bash
# Fix permissions
chmod 600 ~/.ssh/hgl_release_key

# Check ownership
ls -la ~/.ssh/hgl_release_key

# Fix ownership if needed
sudo chown $USER:$USER ~/.ssh/hgl_release_key
```

---

## Verification Issues

### Issue: "Could not verify signature"

**Symptoms:**
```
.github/allowed_signers:5: invalid key
Could not verify signature.
```

**Diagnosis:**
```bash
# Check allowed_signers format
cat .github/allowed_signers

# Check for line wrapping or extra text
cat -A .github/allowed_signers
```

**Solution:**
```bash
# Use minimal format (no dates, no namespaces)
cat > .github/allowed_signers << EOF
# HGL Allowed Signers Registry
release@helixprojectai.com $(ssh-keygen -y -f ~/.ssh/hgl_release_key | awk '{print $1, $2}')
EOF

# Test
ssh-keygen -Y verify \
  -f .github/allowed_signers \
  -I release@helixprojectai.com \
  -n file \
  -s /path/to/SHA256SUMS.txt.sig \
  < /path/to/SHA256SUMS.txt
```

### Issue: "Couldn't parse signature"

**Symptoms:**
```
Couldn't parse signature: missing header
sig_verify: sshsig_armor: invalid format
```

**Diagnosis:**
```bash
# Check first line of signature
head -1 /path/to/SHA256SUMS.txt.sig
```

**Solution:**
```bash
# Should start with: -----BEGIN SSH SIGNATURE-----
# If not, regenerate signature:
rm /path/to/SHA256SUMS.txt.sig
./tools/generate-hashes.sh /path/to/directory --sign
```

### Issue: Wrong Principal

**Symptoms:**
```
No matching principal found for <email>
```

**Solution:**
```bash
# Check what principals are in allowed_signers
grep "^[^#]" .github/allowed_signers

# Use the correct principal when verifying
ssh-keygen -Y verify \
  -f .github/allowed_signers \
  -I <principal-from-file> \
  -n file \
  -s signature.sig \
  < file.txt
```

### Issue: OpenSSH Version Too Old

**Symptoms:**
```
ssh-keygen: illegal option -- Y
```

**Diagnosis:**
```bash
# Check OpenSSH version
ssh -V
```

**Solution:**
```bash
# Need OpenSSH 8.0+ (released 2019)
# Upgrade OpenSSH
sudo apt update
sudo apt install openssh-client

# Or upgrade system
sudo apt dist-upgrade
```

---

## Permission Issues

### Issue: Cannot Write to Repository

**Symptoms:**
```
error: insufficient permission for adding an object to repository database
```

**Solution:**
```bash
# Check ownership
ls -la ~/git/hgl

# Fix ownership
sudo chown -R $USER:$USER ~/git/hgl

# Fix permissions
chmod -R u+rwX ~/git/hgl
```

### Issue: Scripts Not Executable

**Symptoms:**
```
bash: ./tools/verify_and_eval.sh: Permission denied
```

**Solution:**
```bash
# Make scripts executable
chmod +x tools/*.sh tools/*.py

# Verify
ls -la tools/
```

### Issue: Cannot Access SSH Keys

**Symptoms:**
```
Permissions 0777 for '/home/user/.ssh/hgl_release_key' are too open.
```

**Solution:**
```bash
# Fix SSH directory and key permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/hgl_release_key
chmod 644 ~/.ssh/hgl_release_key.pub
chmod 644 ~/.ssh/known_hosts

# Verify
ls -la ~/.ssh/
```

---

## Performance Issues

### Issue: Slow Git Operations

**Diagnosis:**
```bash
# Check repository size
du -sh ~/git/hgl

# Check number of objects
cd ~/git/hgl
git count-objects -vH
```

**Solution:**
```bash
# Clean up repository
git gc --aggressive --prune=now

# Remove unnecessary files
git clean -fdx

# Shallow clone if size is huge
cd ~/git
mv hgl hgl.old
git clone --depth 1 git@github.com:username/repo.git hgl
```

### Issue: High CPU During Signing

**Diagnosis:**
```bash
# Monitor during signing
top -p $(pgrep ssh-keygen)
```

**Solution:**
```bash
# This is normal for ED25519 operations
# Consider upgrading hardware if persistent issue
```

### Issue: Disk Space Full

**Diagnosis:**
```bash
# Check disk usage
df -h

# Find large files
du -h ~/git/hgl | sort -h | tail -20
```

**Solution:**
```bash
# Clean temporary files
rm -rf /tmp/test-* /tmp/final-* /tmp/manual-*

# Clean old backups
find ~/.ssh -name "*.backup" -mtime +90 -delete

# Clean Git
cd ~/git/hgl
git gc --aggressive
git prune
```

---

## Emergency Recovery

### Complete System Reset

If everything is broken:
```bash
# 1. Backup current state
cd ~
tar czf hgl_emergency_backup_$(date +%Y%m%d_%H%M%S).tar.gz git/

# 2. Remove broken installation
rm -rf ~/git/hgl

# 3. Fresh clone
cd ~/git
git clone git@github.com:stephenh67/HELIX-GLYPH-LANGUAGE-HGL-.git hgl

# 4. Restore key from backup
# (If you have encrypted backup)
gpg --decrypt ~/backups/hgl_key_YYYYMMDD.tar.gz.gpg | tar xz -C ~

# 5. Fix permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/hgl_release_key
chmod 644 ~/.ssh/hgl_release_key.pub

# 6. Make scripts executable
cd ~/git/hgl
chmod +x tools/*.sh tools/*.py

# 7. Update allowed_signers
cat > .github/allowed_signers << EOF
release@helixprojectai.com $(ssh-keygen -y -f ~/.ssh/hgl_release_key | awk '{print $1, $2}')
EOF

# 8. Test
./tools/generate-hashes.sh /tmp/recovery-test --sign
./tools/verify_and_eval.sh /tmp/recovery-test

# 9. If tests pass, commit
git add .github/allowed_signers
git commit -m "Recovery: Restore configuration after emergency"
git push origin main
```

---

## Getting Help

### Collect Diagnostic Information
```bash
# Run diagnostic script
~/diagnose_hgl.sh > ~/hgl_diagnostics_$(date +%Y%m%d).txt

# Include:
# - Output of diagnostic script
# - Relevant error messages
# - Steps to reproduce
# - What you've already tried
```

### Report an Issue

1. Go to: https://github.com/stephenh67/HELIX-GLYPH-LANGUAGE-HGL-/issues
2. Click "New Issue"
3. Include diagnostic information
4. Describe the problem clearly
5. List steps to reproduce

---

## Preventive Maintenance

Run these regularly to avoid issues:
```bash
# Weekly
git pull origin main  # Stay up to date
~/audit_hgl_security.sh  # Security check

# Monthly
sudo apt update && sudo apt upgrade  # System updates
~/diagnose_hgl.sh  # System diagnostics
git gc  # Clean repository

# Annually
~/rotate_hgl_key.sh  # Rotate signing keys
```

---

**Last Updated:** 2025-10-23  
**Version:** 1.0.0  
**Maintained By:** HGL Infrastructure Team
