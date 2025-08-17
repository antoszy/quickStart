# Remote Server Setup Script

This script automates the setup of passwordless SSH access and repository cloning on remote Linux servers.

## Features

- ✅ **Passwordless SSH Setup** - Configures SSH key-based authentication
- ✅ **SSH Key Management** - Safely copies and manages SSH keys on remote server
- ✅ **Dependency Installation** - Installs essential tools (curl, wget, git)
- ✅ **Repository Cloning** - Clones this repository to ~/repos on remote server
- ✅ **Security Focused** - Multiple security improvements and validations
- ✅ **Smart Conflict Handling** - Protects existing files and configurations

## Usage

### Basic Usage
```bash
./setup_remote.sh user@hostname
```

### With Environment Variables
```bash
# Custom repository
REPO_URL=git@github.com:username/myrepo.git ./setup_remote.sh user@hostname

# Pre-set SSH password (not recommended for security)
SSH_PASS=mypassword ./setup_remote.sh user@hostname
```

## What the Script Does

### Step 1: SSH Key Detection
- Automatically finds your SSH key pair (ed25519, ed25519_2, or rsa)
- Validates SSH target format

### Step 2: Passwordless SSH Setup
- Copies your public key to remote server
- Handles host key verification automatically
- Uses secure password prompting

### Step 3: SSH Connection Testing
- Verifies passwordless connection works
- Uses the correct private key

### Step 4: SSH Key Management
- Copies your private key to remote ~/.ssh/
- Renames existing keys to avoid conflicts (adds .new suffix)
- Sets proper permissions (600)

### Step 5: Dependencies Installation
- Updates package manager
- Installs: curl, wget, git
- Handles different Linux distributions (apt, yum, dnf)

### Step 6: Repository Setup
- Creates ~/repos directory
- Intelligently handles existing repositories:
  - If git repo exists: pulls latest changes
  - If non-git directory exists: backs up with timestamp
  - If nothing exists: clones fresh copy

## Security Features

- **Secure password prompting** - No passwords in command history
- **SSH target validation** - Prevents injection attacks
- **Host key verification** - Protects against MITM attacks
- **Secure temp files** - Uses mktemp, proper cleanup
- **Password separation** - Separate SSH and sudo passwords
- **File conflict protection** - Backs up existing files

## Prerequisites

### Local Machine
- SSH client
- SSH key pair (will be auto-detected)
- Optional: sshpass for password automation

### Remote Server
- SSH server running
- User account with sudo privileges (optional)
- Linux distribution with package manager

## Supported Systems

### Local
- Linux, macOS, WSL

### Remote
- Ubuntu/Debian (apt-get)
- CentOS/RHEL (yum)
- Fedora (dnf)

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `REPO_URL` | Git repository to clone | `git@github.com:antoszy/quickStart.git` |
| `SSH_PASS` | SSH password (not recommended) | Prompts securely |

## Examples

### Setup development server
```bash
./setup_remote.sh dev@192.168.1.100
```

### Setup with custom repository
```bash
REPO_URL=git@github.com:myuser/myproject.git ./setup_remote.sh user@server.com
```

### Skip password automation
```bash
./setup_remote.sh user@server.com
# Press Enter when prompted for password to use interactive mode
```

## Troubleshooting

### Permission Denied
- Ensure SSH server is running on remote
- Check if user exists on remote server
- Verify network connectivity

### Sudo Password Required
- Script will prompt for sudo password
- Install sshpass for automation: `sudo apt-get install sshpass`

### Repository Clone Fails
- Check if SSH key has access to repository
- Verify repository URL is correct
- Ensure git is installed on remote

### Host Key Verification Failed
- Script automatically handles this
- If issues persist, manually add host key: `ssh-keyscan hostname >> ~/.ssh/known_hosts`

## Security Considerations

- Keep your SSH private keys secure
- Use strong passwords
- Consider using SSH key passphrases
- Regularly rotate SSH keys
- Monitor SSH access logs

## License

This script is provided as-is for educational and development purposes.