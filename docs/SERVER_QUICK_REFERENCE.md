# HGL Server Quick Reference

Quick command reference for common HGL server operations.

## Essential Commands

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

---

## Git Operations
```bash
# Pull latest changes
git pull origin main

# Check status
git status

# View recent commits
git log --oneline -5

# Create and push tag
git tag -a v1.2.0 -m "Release 1.2.0"
git push origin v1.2.0

# Undo last commit (keep changes)
git reset --soft HEAD~1

# View diff
git diff
```

---

## SSH Key Management
```bash
# Display public key
cat ~/.ssh/hgl_release_key.pub

# Get key fingerprint
ssh-keygen -lf ~/.ssh/hgl_release_key.pub

# Test GitHub connection
ssh -T git@github.com

# Add key to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/hgl_release_key

# List loaded keys
ssh-add -l
```

---

## Signing Operations
```bash
# Sign a manifest
ssh-keygen -Y sign -f ~/.ssh/hgl_release_key -n file SHA256SUMS.txt

# Verify a signature
ssh-keygen -Y verify \
  -f .github/allowed_signers \
  -I release@helixprojectai.com \
  -n file \
  -s SHA256SUMS.txt.sig \
  < SHA256SUMS.txt

# Generate hashes only (no signing)
./tools/generate-hashes.sh releases/HGL-vX.Y.Z
```

---

## File Operations
```bash
# Make scripts executable
chmod +x tools/*.sh tools/*.py

# Fix SSH key permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/hgl_release_key
chmod 644 ~/.ssh/hgl_release_key.pub

# View directory tree
tree -L 2 tools/ .github/ docs/

# Find large files
du -h ~/git/hgl | sort -h | tail -10
```

---

## Diagnostics
```bash
# Check system info
uname -a
df -h
free -h

# Check versions
git --version
python3 --version
ssh -V
jq --version

# Run HGL diagnostics
~/diagnose_hgl.sh

# Check allowed_signers
cat .github/allowed_signers

# Test signing
./tools/generate-hashes.sh /tmp/test --sign
```

---

## Troubleshooting
```bash
# Fix permissions
sudo chown -R $USER:$USER ~/git/hgl
chmod -R u+rwX ~/git/hgl

# Regenerate signature file
rm /path/to/SHA256SUMS.txt.sig
./tools/generate-hashes.sh /path/to/directory --sign

# Clean repository
git gc --aggressive

# View logs
sudo journalctl -u ssh -n 50
tail -f ~/.hgl_git.log
```

---

## Maintenance
```bash
# Update system
sudo apt update
sudo apt upgrade -y

# Clean temp files
rm -rf /tmp/test-* /tmp/final-*

# Backup key
tar czf - ~/.ssh/hgl_release_key | \
  gpg --symmetric --cipher-algo AES256 > \
  ~/backups/hgl_key_$(date +%Y%m%d).tar.gz.gpg

# View security audit
~/audit_hgl_security.sh
```

---

## Common File Locations
```
~/git/hgl/                          # Repository
~/.ssh/hgl_release_key              # Private signing key
~/.ssh/hgl_release_key.pub          # Public signing key
~/git/hgl/.github/allowed_signers   # Authorized signers
~/git/hgl/tools/                    # Scripts
~/git/hgl/releases/                 # Release artifacts
~/git/hgl/docs/                     # Documentation
```

---

## Environment Variables
```bash
# Set custom signing key
export SSH_KEY=~/.ssh/custom_key

# Set releases directory
export HGL_RELEASES_DIR=/opt/helix/releases

# View all HGL-related env vars
env | grep -i hgl
```

---

## Script Options

### generate-hashes.sh
```bash
./tools/generate-hashes.sh <directory>           # Generate hashes
./tools/generate-hashes.sh <directory> --sign    # Generate and sign
./tools/generate-hashes.sh --help                # Show help
```

### verify_and_eval.sh
```bash
./tools/verify_and_eval.sh <directory>      # Full verification
./tools/verify_and_eval.sh --help           # Show help
./tools/verify_and_eval.sh --verbose        # Verbose output
```

### generate_provenance.py
```bash
python3 tools/generate_provenance.py <directory>     # Generate provenance
python3 tools/generate_provenance.py --help          # Show help
```

---

## Emergency Procedures

### Key Compromised
```bash
# 1. Generate new key immediately
ssh-keygen -t ed25519 -f ~/.ssh/hgl_release_key_emergency

# 2. Update allowed_signers
cat >> .github/allowed_signers << EOF
release@helixprojectai.com $(ssh-keygen -y -f ~/.ssh/hgl_release_key_emergency | awk '{print $1, $2}')
EOF

# 3. Commit and push
git add .github/allowed_signers
git commit -m "SECURITY: Emergency key rotation"
git push origin main
```

### Verification Failing
```bash
# 1. Check key fingerprint matches
ssh-keygen -lf ~/.ssh/hgl_release_key.pub

# 2. Verify allowed_signers format
cat .github/allowed_signers

# 3. Test with minimal format
echo "release@helixprojectai.com $(ssh-keygen -y -f ~/.ssh/hgl_release_key | awk '{print $1, $2}')" > /tmp/test_signers
ssh-keygen -Y verify -f /tmp/test_signers -I release@helixprojectai.com -n file -s signature.sig < file.txt
```

### Repository Corrupted
```bash
# 1. Backup current state
tar czf ~/hgl_backup_$(date +%Y%m%d).tar.gz ~/git/hgl

# 2. Fresh clone
rm -rf ~/git/hgl
cd ~/git
git clone git@github.com:stephenh67/HELIX-GLYPH-LANGUAGE-HGL-.git hgl

# 3. Restore configuration
# (Restore keys, update allowed_signers, test)
```

---

## Useful One-Liners
```bash
# List all releases
ls -1 releases/

# Count files in all releases
find releases/ -type f | wc -l

# Find releases without signatures
find releases/ -type d -mindepth 1 ! -exec test -f {}/SHA256SUMS.txt.sig \; -print

# Verify all releases
for r in releases/HGL-*; do echo "=== $r ==="; ./tools/verify_and_eval.sh "$r"; done

# Get all key fingerprints
grep "^[^#]" .github/allowed_signers | while read line; do echo "$line" | ssh-keygen -lf /dev/stdin; done

# Check last 10 Git operations
git reflog -10

# Find when key was last used
ls -lt ~/.ssh/hgl_release_key*
```

---

## Keyboard Shortcuts

### Nano Editor
- `Ctrl+X` - Exit
- `Ctrl+O` - Save
- `Ctrl+W` - Search
- `Ctrl+K` - Cut line
- `Ctrl+U` - Paste

### Less Pager
- `Space` - Next page
- `b` - Previous page
- `/pattern` - Search forward
- `q` - Quit

### Bash
- `Ctrl+C` - Cancel command
- `Ctrl+Z` - Suspend process
- `Ctrl+R` - Search history
- `Ctrl+L` - Clear screen

---

## Status Codes

### Git Exit Codes
- `0` - Success
- `1` - Generic error
- `128` - Git command failed

### SSH Exit Codes
- `0` - Success
- `255` - SSH error

### Common Errors
- `Permission denied` - Check file/key permissions
- `Command not found` - Install missing package
- `fatal: not a git repository` - Run from correct directory
- `Could not verify signature` - Check allowed_signers format

---

## URLs

- **Repository:** https://github.com/stephenh67/HELIX-GLYPH-LANGUAGE-HGL-
- **Issues:** https://github.com/stephenh67/HELIX-GLYPH-LANGUAGE-HGL-/issues
- **SSH Keys:** https://github.com/settings/keys
- **Docs:** ~/git/hgl/docs/

---

## Contact

- **Security Issues:** [SECURITY.md](../SECURITY.md)
- **Support:** [GitHub Issues](https://github.com/stephenh67/HELIX-GLYPH-LANGUAGE-HGL-/issues)
- **Documentation:** `docs/` directory

---

**Print this page for quick desk reference!**

**Last Updated:** 2025-10-23  
**Version:** 1.0.0
