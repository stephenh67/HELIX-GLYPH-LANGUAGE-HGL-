# HGL Server Security Hardening Guide

Security best practices for production HGL infrastructure.

## Table of Contents

1. [System Hardening](#system-hardening)
2. [SSH Security](#ssh-security)
3. [Key Management](#key-management)
4. [Access Control](#access-control)
5. [Audit Logging](#audit-logging)
6. [Network Security](#network-security)
7. [Compliance](#compliance)

---

## System Hardening

### Keep System Updated
```bash
# Configure automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Manual updates
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
```

### Minimize Installed Packages
```bash
# List installed packages
dpkg --get-selections | grep -v deinstall

# Remove unnecessary packages
sudo apt remove package-name
sudo apt autoremove
```

### Configure Firewall
```bash
# Install UFW (Uncomplicated Firewall)
sudo apt install ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTPS (for Git over HTTPS)
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

### Disable Unnecessary Services
```bash
# List running services
systemctl list-units --type=service --state=running

# Disable unnecessary services
sudo systemctl disable service-name
sudo systemctl stop service-name
```

---

## SSH Security

### Harden SSH Configuration
```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config
```

Recommended settings:
```
# Disable root login
PermitRootLogin no

# Use public key authentication only
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no

# Disable empty passwords
PermitEmptyPasswords no

# Limit authentication attempts
MaxAuthTries 3
MaxSessions 5

# Use strong ciphers only
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# Disable X11 forwarding
X11Forwarding no

# Use strong key exchange algorithms
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# Set idle timeout
ClientAliveInterval 300
ClientAliveCountMax 2
```

Restart SSH:
```bash
sudo systemctl restart sshd
```

### Use SSH Key Authentication
```bash
# Generate strong SSH key (if not already done)
ssh-keygen -t ed25519 -a 100

# Copy public key to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@server

# Test key-based login
ssh -i ~/.ssh/id_ed25519 user@server

# Disable password authentication (see above)
```

### Configure Fail2Ban

Protect against brute-force attacks:
```bash
# Install Fail2Ban
sudo apt install fail2ban

# Create local config
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Edit config
sudo nano /etc/fail2ban/jail.local
```

Configure SSH protection:
```
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
```

Start Fail2Ban:
```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Check status
sudo fail2ban-client status sshd
```

---

## Key Management

### Private Key Protection
```bash
# Set restrictive permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/hgl_release_key
chmod 644 ~/.ssh/hgl_release_key.pub

# Verify
ls -la ~/.ssh/
```

### Use Strong Passphrases

- Minimum 20 characters
- Mix of uppercase, lowercase, numbers, symbols
- Use a password manager
- Don't reuse passphrases

### Key Storage Best Practices

**DO:**
- ✅ Store private keys only on secure servers
- ✅ Use encrypted backups
- ✅ Use hardware security modules (HSM) for critical keys
- ✅ Rotate keys annually
- ✅ Document key fingerprints
- ✅ Use separate keys for different purposes

**DON'T:**
- ❌ Store keys in source control
- ❌ Share private keys
- ❌ Email keys
- ❌ Store keys in cloud storage without encryption
- ❌ Use weak passphrases
- ❌ Reuse keys across systems

### Encrypted Key Backup
```bash
# Backup with GPG encryption
tar czf - ~/.ssh/hgl_release_key | \
  gpg --symmetric --cipher-algo AES256 \
  --output hgl_key_backup_$(date +%Y%m%d).tar.gz.gpg

# Restore backup
gpg --decrypt hgl_key_backup_YYYYMMDD.tar.gz.gpg | \
  tar xz -C ~/.ssh/

# Set correct permissions
chmod 600 ~/.ssh/hgl_release_key
```

### Key Rotation Schedule

Implement annual key rotation:
```bash
# Create key rotation script
cat > ~/rotate_hgl_key.sh << 'EOF'
#!/usr/bin/env bash
# HGL Key Rotation Script

YEAR=$(date +%Y)
OLD_KEY=~/.ssh/hgl_release_key
NEW_KEY=~/.ssh/hgl_release_key_${YEAR}

echo "=== HGL Key Rotation ==="
echo "Date: $(date)"
echo

# Generate new key
echo "Generating new key..."
ssh-keygen -t ed25519 -f "$NEW_KEY" -C "release@helixprojectai.com"

# Display new public key
echo
echo "New public key:"
ssh-keygen -y -f "$NEW_KEY" | awk '{print $1, $2}'
echo

# Backup old key
echo "Backing up old key..."
cp "$OLD_KEY" "${OLD_KEY}_$(date +%Y%m%d)_retired"
cp "${OLD_KEY}.pub" "${OLD_KEY}.pub_$(date +%Y%m%d)_retired"

# Instructions
echo
echo "Next steps:"
echo "1. Add new key to .github/allowed_signers"
echo "2. Test with: export SSH_KEY=$NEW_KEY && ./tools/generate-hashes.sh /tmp --sign"
echo "3. Commit changes to GitHub"
echo "4. Replace: mv $NEW_KEY $OLD_KEY"
echo "5. Update documentation"
EOF

chmod +x ~/rotate_hgl_key.sh
```

---

## Access Control

### User Management
```bash
# Create dedicated service account (optional)
sudo useradd -m -s /bin/bash hgl-service
sudo usermod -aG sudo hgl-service

# Set up SSH key for service account
sudo -u hgl-service ssh-keygen -t ed25519
```

### Sudo Configuration
```bash
# Edit sudoers file
sudo visudo

# Add specific permissions (avoid NOPASSWD in production)
username ALL=(ALL) /usr/bin/git, /usr/bin/ssh-keygen
```

### File Permissions Audit
```bash
# Check repository permissions
find ~/git/hgl -type f -perm /o+w -ls

# Check SSH directory
ls -la ~/.ssh/

# Check for world-readable private keys (should return nothing)
find ~/.ssh -name "*.key" -o -name "*_rsa" -o -name "*_ed25519" | xargs ls -l | grep -v "^-rw-------"
```

### Git Commit Signing

Require signed commits:
```bash
# Configure Git to require signed commits
git config --global user.signingkey ~/.ssh/hgl_release_key
git config --global gpg.format ssh
git config --global commit.gpgsign true

# Sign a commit
git commit -S -m "Signed commit"

# Verify commit signature
git log --show-signature -1
```

---

## Audit Logging

### Enable Audit Logging
```bash
# Install auditd
sudo apt install auditd audispd-plugins

# Configure audit rules
sudo nano /etc/audit/rules.d/hgl.rules
```

Add these rules:
```
# Monitor HGL directory
-w /home/user/git/hgl/ -p wa -k hgl_changes

# Monitor SSH keys
-w /home/user/.ssh/ -p wa -k hgl_keys

# Monitor allowed_signers
-w /home/user/git/hgl/.github/allowed_signers -p wa -k hgl_signers

# Monitor signing operations
-a always,exit -F arch=b64 -S execve -F path=/usr/bin/ssh-keygen -k hgl_signing
```

Reload rules:
```bash
sudo augenrules --load
sudo systemctl restart auditd
```

### Query Audit Logs
```bash
# View HGL-related events
sudo ausearch -k hgl_changes

# View key access
sudo ausearch -k hgl_keys

# View signing operations
sudo ausearch -k hgl_signing

# Generate audit report
sudo aureport --start today
```

### Git Activity Logging
```bash
# Create Git hooks for logging
cat > ~/git/hgl/.git/hooks/post-commit << 'EOF'
#!/bin/bash
echo "$(date): Commit by $(git config user.name) - $(git log -1 --pretty=%B)" >> ~/.hgl_git.log
EOF

chmod +x ~/git/hgl/.git/hooks/post-commit
```

### Centralized Logging

Send logs to remote syslog server:
```bash
# Configure rsyslog
sudo nano /etc/rsyslog.d/50-hgl.conf
```

Add:
```
# Send HGL logs to remote server
:msg, contains, "hgl_" @@log-server.example.com:514
```

Restart rsyslog:
```bash
sudo systemctl restart rsyslog
```

---

## Network Security

### Secure Git Operations

Use SSH for Git operations:
```bash
# Check current remote
git remote -v

# Switch to SSH if using HTTPS
git remote set-url origin git@github.com:username/repo.git
```

### Network Monitoring
```bash
# Monitor network connections
sudo netstat -tunap | grep ESTABLISHED

# Check for unusual connections
sudo ss -tunap

# Monitor DNS queries
sudo tcpdump -i any port 53
```

### Intrusion Detection

Install AIDE (Advanced Intrusion Detection Environment):
```bash
# Install AIDE
sudo apt install aide

# Initialize database
sudo aideinit

# Check for changes
sudo aide --check

# Update database after legitimate changes
sudo aide --update
```

---

## Compliance

### Documentation Requirements

Maintain documentation for:

- Key fingerprints and expiration dates
- Access control lists
- Incident response procedures
- Backup and recovery procedures
- Security update schedule

### Regular Security Audits
```bash
# Create security audit script
cat > ~/audit_hgl_security.sh << 'EOF'
#!/usr/bin/env bash
# HGL Security Audit

echo "=== HGL Security Audit ==="
echo "Date: $(date)"
echo

# Check file permissions
echo "Checking file permissions..."
find ~/.ssh -type f -name "*hgl*" ! -perm 600 | head -5
find ~/git/hgl/.github -type f ! -perm 644 | head -5

# Check for outdated packages
echo
echo "Checking for security updates..."
sudo apt list --upgradable 2>/dev/null | grep -i security

# Check SSH configuration
echo
echo "Checking SSH hardening..."
grep -E "^(PasswordAuthentication|PermitRootLogin|PubkeyAuthentication)" /etc/ssh/sshd_config

# Check firewall status
echo
echo "Checking firewall..."
sudo ufw status

# Check fail2ban
echo
echo "Checking Fail2Ban..."
sudo fail2ban-client status sshd 2>/dev/null

# Check key expiration
echo
echo "Key information:"
ssh-keygen -lf ~/.ssh/hgl_release_key.pub

echo
echo "=== Audit Complete ==="
EOF

chmod +x ~/audit_hgl_security.sh
```

Run monthly:
```bash
# Schedule monthly audit
(crontab -l 2>/dev/null; echo "0 0 1 * * ~/audit_hgl_security.sh > ~/hgl_audit_\$(date +\%Y\%m).log 2>&1") | crontab -
```

### Incident Response Plan

Document and test:

1. **Detection:** How to identify security incidents
2. **Containment:** Immediate actions to limit damage
3. **Investigation:** Forensic analysis procedures
4. **Recovery:** Steps to restore normal operations
5. **Post-Incident:** Lessons learned and improvements

---

## Security Checklist

### Initial Setup
- [ ] System fully updated
- [ ] Unnecessary services disabled
- [ ] Firewall configured and enabled
- [ ] SSH hardened
- [ ] Fail2Ban configured
- [ ] Private keys protected (600 permissions)
- [ ] Strong passphrases used
- [ ] Audit logging enabled

### Monthly
- [ ] Security updates applied
- [ ] Audit logs reviewed
- [ ] Failed login attempts checked
- [ ] File permission audit
- [ ] Backup verification
- [ ] Security scan completed

### Annually
- [ ] Key rotation performed
- [ ] Access control review
- [ ] Incident response plan tested
- [ ] Security policy review
- [ ] Compliance audit
- [ ] Disaster recovery test

---

## Emergency Contacts

Document and maintain:

- Security team contacts
- Incident response team
- On-call rotation
- Escalation procedures

---

## References

- **NIST Cybersecurity Framework:** https://www.nist.gov/cyberframework
- **CIS Benchmarks:** https://www.cisecurity.org/cis-benchmarks/
- **OWASP Top 10:** https://owasp.org/www-project-top-ten/

---

**Last Updated:** 2025-10-23  
**Version:** 1.0.0  
**Maintained By:** HGL Security Team
