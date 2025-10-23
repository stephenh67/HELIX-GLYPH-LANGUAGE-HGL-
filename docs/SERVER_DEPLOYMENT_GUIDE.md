# HGL Server Deployment Guide

Complete guide for deploying HGL verification infrastructure on production servers.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Server Setup](#initial-server-setup)
3. [Repository Deployment](#repository-deployment)
4. [Key Generation](#key-generation)
5. [Configuration](#configuration)
6. [Testing](#testing)
7. [Going Live](#going-live)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Server Requirements

**Operating System:**
- Ubuntu 20.04 LTS or newer
- Debian 11 or newer
- Any Linux with OpenSSH 8.0+

**Hardware Minimum:**
- 2 CPU cores
- 2GB RAM
- 10GB disk space
- Network connectivity to GitHub

**Software:**
- SSH access with sudo privileges
- Git 2.20+
- OpenSSH 8.0+
- Python 3.8+
- Bash 4.0+

### Access Requirements

- SSH key access to GitHub (for cloning)
- Sudo privileges on server
- Ability to generate SSH keys
- Network access to github.com

---

## Initial Server Setup

### Step 1: Connect to Server
```bash
# SSH into your server
ssh username@your-server.example.com

# Verify you have sudo access
sudo -v
```

### Step 2: Install Dependencies
```bash
# Update package lists
sudo apt update

# Install required packages
sudo apt install -y \
  tree \
  curl \
  wget \
  unzip \
  git \
  python3 \
  python3-pip \
  openssh-client \
  jq \
  build-essential \
  python3-jsonschema \
  python3-yaml

# Verify installations
tree --version
git --version
python3 --version
ssh-keygen -V 2>&1 | head -1
jq --version
```

**Expected output:**
```
tree v2.x.x
git version 2.x.x
Python 3.x.x
ssh-keygen: unknown option -- V
jq-1.x
```

### Step 3: Configure Git
```bash
# Set global Git configuration
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Verify
git config --global --list
```

---

## Repository Deployment

### Step 1: Set Up SSH Access to GitHub

**Option A: Generate New SSH Key**
```bash
# Generate SSH key for GitHub
ssh-keygen -t ed25519 -C "your.email@example.com"
# Press Enter to accept default location (~/.ssh/id_ed25519)
# Enter passphrase (recommended) or leave blank

# Display public key
cat ~/.ssh/id_ed25519.pub

# Copy the output and add to GitHub:
# 1. Go to https://github.com/settings/keys
# 2. Click "New SSH key"
# 3. Paste the public key
# 4. Click "Add SSH key"

# Test connection
ssh -T git@github.com
# Should see: "Hi username! You've successfully authenticated..."
```

**Option B: Use Existing SSH Key**
```bash
# If you already have an SSH key, display it
cat ~/.ssh/id_ed25519.pub || cat ~/.ssh/id_rsa.pub

# Add to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Test connection
ssh -T git@github.com
```

### Step 2: Clone HGL Repository
```bash
# Create directory structure
mkdir -p ~/git
cd ~/git

# Clone the repository (SSH)
git clone git@github.com:stephenh67/HELIX-GLYPH-LANGUAGE-HGL-.git hgl

# Or use HTTPS if SSH is not available
git clone https://github.com/stephenh67/HELIX-GLYPH-LANGUAGE-HGL-.git hgl

# Enter the directory
cd hgl

# Verify you're on main branch
git branch
git status

# Verify files are present
ls -la tools/ .github/ docs/
```

**Expected directory structure:**
```
hgl/
├── .github/
│   ├── allowed_signers
│   └── workflows/
├── docs/
│   ├── DEPLOYMENT_CHECKLIST.md
│   ├── HGL_GAP_ANALYSIS.md
│   ├── IMPLEMENTATION_README.md
│   └── PACKAGE_INDEX.md
├── tools/
│   ├── generate-hashes.sh
│   ├── generate_provenance.py
│   └── verify_and_eval.sh
└── README.md
```

### Step 3: Set File Permissions
```bash
# Make scripts executable
chmod +x tools/*.sh tools/*.py

# Verify permissions
ls -la tools/
```

**Expected output:**
```
-rwxr-xr-x 1 user user  ... generate-hashes.sh
-rwxr-xr-x 1 user user  ... generate_provenance.py
-rwxr-xr-x 1 user user  ... verify_and_eval.sh
```

---

## Key Generation

### Step 1: Generate Release Signing Key
```bash
# Generate ED25519 key for signing releases
ssh-keygen -t ed25519 \
  -f ~/.ssh/hgl_release_key \
  -C "release@helixprojectai.com"

# Enter a STRONG passphrase
# For automated systems, you can use -N "" for no passphrase (less secure)

# Verify key was created
ls -la ~/.ssh/hgl_release_key*
```

**Expected output:**
```
-rw------- 1 user user  464 Oct 23 12:00 /home/user/.ssh/hgl_release_key
-rw-r--r-- 1 user user  109 Oct 23 12:00 /home/user/.ssh/hgl_release_key.pub
```

### Step 2: Display Public Key
```bash
# Display the public key
cat ~/.ssh/hgl_release_key.pub
```

**Example output:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMZUhHXsFyWPogC4Vj89ZNQfDr0s+rG1EzeW8ePtJcch release@helixprojectai.com
```

**Save this output** - you'll need it for the next step.

### Step 3: Secure the Private Key
```bash
# Set correct permissions
chmod 600 ~/.ssh/hgl_release_key
chmod 644 ~/.ssh/hgl_release_key.pub

# Verify
ls -la ~/.ssh/hgl_release_key*
```

### Step 4: Optional - Use ssh-agent for Passphrase Caching

If you used a passphrase, add the key to ssh-agent:
```bash
# Start ssh-agent
eval "$(ssh-agent -s)"

# Add key to agent
ssh-add ~/.ssh/hgl_release_key

# Verify key is loaded
ssh-add -l
```

---

## Configuration

### Step 1: Update allowed_signers
```bash
# Create clean allowed_signers file
cat > .github/allowed_signers << 'EOF'
# HGL Allowed Signers Registry - Production Server
release@helixprojectai.com ssh-ed25519 PASTE_YOUR_PUBLIC_KEY_HERE
EOF

# Replace PASTE_YOUR_PUBLIC_KEY_HERE with your actual public key
# Get your key (just the key data, no comment):
ssh-keygen -y -f ~/.ssh/hgl_release_key | awk '{print $1, $2}'
```

**Manual edit method:**
```bash
# Open editor
nano .github/allowed_signers

# The line should look like:
# release@helixprojectai.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...

# Save: Ctrl+X, Y, Enter
```

**Automated method:**
```bash
# Automatically create allowed_signers with your key
cat > .github/allowed_signers << EOF
# HGL Allowed Signers Registry - Production Server
release@helixprojectai.com $(ssh-keygen -y -f ~/.ssh/hgl_release_key | awk '{print $1, $2}')
EOF

# Verify the file
cat .github/allowed_signers
```

### Step 2: Verify Configuration
```bash
# Check allowed_signers format
cat .github/allowed_signers

# Should be a single line (plus comments) like:
# release@helixprojectai.com ssh-ed25519 AAAAC3...
```

---

## Testing

### Step 1: Test Hash Generation
```bash
# Create test release directory
mkdir -p /tmp/test-release
echo "test content" > /tmp/test-release/test.txt

# Generate hashes (no signing yet)
./tools/generate-hashes.sh /tmp/test-release

# Verify manifest was created
cat /tmp/test-release/SHA256SUMS.txt
```

**Expected output:**
```
✓ Generated 1 hashes
✓ Manifest saved to: /tmp/test-release/SHA256SUMS.txt
```

### Step 2: Test Signing
```bash
# Generate hashes with signing
./tools/generate-hashes.sh /tmp/test-release --sign

# Check files were created
ls -la /tmp/test-release/

# Should see:
# - SHA256SUMS.txt (hash manifest)
# - SHA256SUMS.txt.sig (SSH signature)
```

**Expected output:**
```
▶ Generating SHA256 manifest for: /tmp/test-release
▶ Found 1 files to hash
✓ Generated 1 hashes
✓ Manifest saved to: /tmp/test-release/SHA256SUMS.txt
▶ Signing manifest...
✓ Signature saved to: /tmp/test-release/SHA256SUMS.txt.sig
✓ Done!
```

### Step 3: Test Verification
```bash
# Verify the signature
ssh-keygen -Y verify \
  -f .github/allowed_signers \
  -I release@helixprojectai.com \
  -n file \
  -s /tmp/test-release/SHA256SUMS.txt.sig \
  < /tmp/test-release/SHA256SUMS.txt
```

**Expected output:**
```
Good "file" signature for release@helixprojectai.com with ED25519 key SHA256:...
```

✅ If you see "Good signature" - **everything is working!**

❌ If you see errors, see [Troubleshooting](#troubleshooting) section.

### Step 4: Test Complete Verification Script
```bash
# Test the verification script help
./tools/verify_and_eval.sh --help

# Create a more complete test release
mkdir -p /tmp/full-test-release
echo "file1" > /tmp/full-test-release/file1.txt
echo "file2" > /tmp/full-test-release/file2.txt

# Generate signed manifest
./tools/generate-hashes.sh /tmp/full-test-release --sign

# Run full verification
./tools/verify_and_eval.sh /tmp/full-test-release
```

### Step 5: Test Provenance Generation
```bash
# Generate provenance manifest
python3 tools/generate_provenance.py /tmp/test-release

# Check provenance file
cat /tmp/test-release/provenance.json
```

---

## Going Live

### Step 1: Commit Configuration
```bash
# Stage the allowed_signers file
git add .github/allowed_signers

# Commit
git commit -m "Security: Add production server signing key

- Add ED25519 public key for production server
- Key fingerprint: SHA256:$(ssh-keygen -lf ~/.ssh/hgl_release_key.pub | awk '{print $2}')
- Valid from: $(date +%Y-%m-%d)"

# Push to GitHub
git push origin main
```

### Step 2: Verify GitHub Update
```bash
# Check that push succeeded
git log --oneline -1

# Verify on GitHub
# Go to: https://github.com/stephenh67/HELIX-GLYPH-LANGUAGE-HGL-/blob/main/.github/allowed_signers
```

### Step 3: Set Up Production Location

If your production releases are in a different location:
```bash
# Create production releases directory
sudo mkdir -p /opt/helix/releases
sudo chown $USER:$USER /opt/helix/releases

# Create symlink from repo
ln -s /opt/helix/releases ~/git/hgl/releases

# Or set environment variable
echo 'export HGL_RELEASES_DIR=/opt/helix/releases' >> ~/.bashrc
source ~/.bashrc
```

### Step 4: Document Your Setup

Create a local README for your team:
```bash
cat > ~/git/hgl/SERVER_INFO.md << EOF
# HGL Server Configuration

**Server:** $(hostname)
**Location:** $(pwd)
**Signing Key:** ~/.ssh/hgl_release_key
**Key Fingerprint:** $(ssh-keygen -lf ~/.ssh/hgl_release_key.pub | awk '{print $2}')
**Deployed:** $(date)
**Deployed By:** $USER

## Quick Commands

Sign a release:
\`\`\`bash
./tools/generate-hashes.sh releases/HGL-vX.Y.Z --sign
\`\`\`

Verify a release:
\`\`\`bash
./tools/verify_and_eval.sh releases/HGL-vX.Y.Z
\`\`\`

Generate provenance:
\`\`\`bash
python3 tools/generate_provenance.py releases/HGL-vX.Y.Z
\`\`\`
EOF

cat SERVER_INFO.md
```

---

## Troubleshooting

### Issue: "Permission denied (publickey)" when cloning

**Cause:** SSH key not added to GitHub

**Solution:**
```bash
# Display your public key
cat ~/.ssh/id_ed25519.pub

# Add to GitHub at: https://github.com/settings/keys
# Then test:
ssh -T git@github.com
```

### Issue: "Could not verify signature"

**Cause 1:** Wrong format in allowed_signers

**Solution:**
```bash
# Use minimal format (no quotes, no dates, no namespaces)
echo "release@helixprojectai.com $(ssh-keygen -y -f ~/.ssh/hgl_release_key | awk '{print $1, $2}')" > .github/allowed_signers
```

**Cause 2:** Wrong principal specified

**Solution:**
```bash
# Check what principal is in allowed_signers
grep "^[^#]" .github/allowed_signers

# Use that exact email when verifying
ssh-keygen -Y verify -f .github/allowed_signers -I <principal-from-file> ...
```

### Issue: "Couldn't parse signature: missing header"

**Cause:** Signature file corrupted or contains prompt text

**Solution:**
```bash
# Check signature file
head -1 /path/to/SHA256SUMS.txt.sig

# Should start with: -----BEGIN SSH SIGNATURE-----
# If not, delete and regenerate:
rm /path/to/SHA256SUMS.txt.sig
./tools/generate-hashes.sh /path/to/release --sign
```

### Issue: Scripts not executable

**Solution:**
```bash
chmod +x tools/*.sh tools/*.py
```

### Issue: "ssh-keygen: command not found"

**Solution:**
```bash
sudo apt install openssh-client
```

### Issue: "jq: command not found"

**Solution:**
```bash
sudo apt install jq
```

### Issue: Python import errors

**Solution:**
```bash
# Install Python packages
sudo apt install python3-jsonschema python3-yaml
```

### Issue: Passphrase prompt hangs

**Cause:** Key has passphrase but no ssh-agent running

**Solution:**
```bash
# Start ssh-agent and add key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/hgl_release_key

# Or regenerate without passphrase (less secure):
rm ~/.ssh/hgl_release_key*
ssh-keygen -t ed25519 -f ~/.ssh/hgl_release_key -C "release@helixprojectai.com" -N ""
```

---

## Security Best Practices

### Protect Private Keys
```bash
# Ensure proper permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/hgl_release_key
chmod 644 ~/.ssh/hgl_release_key.pub

# Verify
ls -la ~/.ssh/hgl_release_key*
```

### Use Passphrases

- ✅ **DO** use strong passphrases for production keys
- ✅ **DO** use ssh-agent to cache passphrases
- ❌ **DON'T** use empty passphrases on production servers
- ❌ **DON'T** store passphrases in plaintext

### Key Rotation
```bash
# Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/hgl_release_key_new -C "release@helixprojectai.com"

# Test with new key before rotating
# Update allowed_signers with new key
# Keep old key valid for verification of old releases
```

### Backup Keys
```bash
# Backup private key to secure location (encrypted USB, password manager, etc.)
# DO NOT commit to Git or store in plaintext!

# Backup public key (safe to store anywhere)
cp ~/.ssh/hgl_release_key.pub ~/backups/hgl_release_key_$(date +%Y%m%d).pub
```

---

## Next Steps

1. ✅ Read [SERVER_OPERATIONS_GUIDE.md](SERVER_OPERATIONS_GUIDE.md) for day-to-day operations
2. ✅ Review [SERVER_SECURITY_HARDENING.md](SERVER_SECURITY_HARDENING.md) for security
3. ✅ Check [SERVER_TROUBLESHOOTING.md](SERVER_TROUBLESHOOTING.md) for common issues
4. ✅ See [SERVER_QUICK_REFERENCE.md](SERVER_QUICK_REFERENCE.md) for command cheatsheet

---

## Support

- **Documentation:** `docs/` directory
- **Issues:** https://github.com/stephenh67/HELIX-GLYPH-LANGUAGE-HGL-/issues
- **Security:** See [SECURITY.md](../SECURITY.md)

---

**Last Updated:** 2025-10-23  
**Version:** 1.0.0  
**Maintained By:** HGL Infrastructure Team
