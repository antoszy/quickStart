#!/bin/bash

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <ssh_ip>"
    echo "Example: $0 user@192.168.1.100"
    echo ""
    echo "Environment variables:"
    echo "  REPO_URL - Git repository URL (default: git@github.com:antoszy/quickStart.git)"
    echo "  SSH_PASS - SSH password (will prompt if not set)"
    echo ""
    echo "The script will securely prompt for password if needed."
    exit 1
fi

SSH_TARGET="$1"

# Validate SSH target format
if ! echo "$SSH_TARGET" | grep -E '^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$' >/dev/null; then
    echo "Error: Invalid SSH target format. Expected: user@hostname"
    echo "Example: user@192.168.1.100 or user@server.domain.com"
    exit 1
fi

# Prompt for password securely (only if environment variable not set)
if [ -z "$SSH_PASS" ]; then
    echo "This script will set up passwordless SSH access and clone the repository."
    echo "You may be prompted for your SSH password initially."
    echo ""
    read -s -p "Enter SSH password for $SSH_TARGET (or press Enter to skip automated password): " SSH_PASS
    echo ""
fi

# Prompt for sudo password separately for better security
SUDO_PASS=""
if [ -n "$SSH_PASS" ]; then
    echo ""
    read -s -p "Enter sudo password for remote server (or press Enter if same as SSH): " SUDO_PASS
    echo ""
    if [ -z "$SUDO_PASS" ]; then
        SUDO_PASS="$SSH_PASS"
    fi
fi

# Check if sshpass is available for password automation
if [ -n "$SSH_PASS" ] && ! command -v sshpass &> /dev/null; then
    echo "Warning: sshpass not found. Install with: sudo apt-get install sshpass"
    echo "Password automation will be limited. You may be prompted for passwords during setup."
    SSH_PASS=""
fi

echo "Setting up remote server: $SSH_TARGET"

echo "Step 1: Finding SSH key pair..."
# Find matching public/private key pairs
if [ -f ~/.ssh/id_ed25519 ] && [ -f ~/.ssh/id_ed25519.pub ]; then
    SSH_KEY="$HOME/.ssh/id_ed25519"
    SSH_PUB_KEY="$HOME/.ssh/id_ed25519.pub"
elif [ -f ~/.ssh/id_ed25519_2 ] && [ -f ~/.ssh/id_ed25519_2.pub ]; then
    SSH_KEY="$HOME/.ssh/id_ed25519_2"
    SSH_PUB_KEY="$HOME/.ssh/id_ed25519_2.pub"
elif [ -f ~/.ssh/id_rsa ] && [ -f ~/.ssh/id_rsa.pub ]; then
    SSH_KEY="$HOME/.ssh/id_rsa"
    SSH_PUB_KEY="$HOME/.ssh/id_rsa.pub"
else
    echo "Error: No matching SSH key pair found (looking for id_rsa, id_ed25519, or id_ed25519_2)"
    exit 1
fi

echo "Using SSH key pair: $SSH_KEY / $SSH_PUB_KEY"

echo "Step 2: Setting up passwordless SSH access..."

# Extract hostname for host key verification
HOSTNAME=$(echo "$SSH_TARGET" | cut -d'@' -f2)
echo "Checking SSH host key for $HOSTNAME..."

# Check if host key is already known
if ssh-keygen -F "$HOSTNAME" >/dev/null 2>&1; then
    echo "Host key already known for $HOSTNAME"
else
    echo "Host key not found. Adding host key to known_hosts..."
    # Use ssh-keyscan to get the host key safely
    if ! ssh-keyscan -H "$HOSTNAME" >> ~/.ssh/known_hosts 2>/dev/null; then
        echo "Warning: Could not retrieve host key. Proceeding with strict host key checking disabled."
        SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    else
        echo "Host key added successfully"
        SSH_OPTS=""
    fi
fi

if [ -n "$SSH_PASS" ]; then
    if ! sshpass -p "$SSH_PASS" ssh-copy-id $SSH_OPTS -i "$SSH_PUB_KEY" "$SSH_TARGET"; then
        echo "Error: Failed to copy SSH key to remote server"
        exit 1
    fi
else
    if ! ssh-copy-id $SSH_OPTS -i "$SSH_PUB_KEY" "$SSH_TARGET"; then
        echo "Error: Failed to copy SSH key to remote server"
        exit 1
    fi
fi

echo "Step 3: Testing SSH connection..."
if ! ssh -i "$SSH_KEY" "$SSH_TARGET" "echo 'SSH connection successful'"; then
    echo "Error: SSH connection test failed"
    exit 1
fi

echo "Step 4: Copying SSH private key to remote server..."

KEY_NAME=$(basename "$SSH_KEY")
echo "Copying SSH key: $SSH_KEY"

# Ensure remote ~/.ssh directory exists with proper permissions
ssh -i "$SSH_KEY" "$SSH_TARGET" "mkdir -p ~/.ssh && chmod 700 ~/.ssh"

# Check if key already exists on remote and rename if needed
TEMP_FILE=$(ssh -i "$SSH_KEY" "$SSH_TARGET" "mktemp")
ssh -i "$SSH_KEY" "$SSH_TARGET" "
if [ -f ~/.ssh/$KEY_NAME ]; then
    echo 'SSH key already exists on remote, will rename copied key to ${KEY_NAME}.new'
    REMOTE_KEY_NAME='${KEY_NAME}.new'
else
    REMOTE_KEY_NAME='$KEY_NAME'
fi
echo \$REMOTE_KEY_NAME > '$TEMP_FILE'
"

REMOTE_KEY_NAME=$(ssh -i "$SSH_KEY" "$SSH_TARGET" "cat '$TEMP_FILE'")
if ! scp -i "$SSH_KEY" "$SSH_KEY" "$SSH_TARGET:~/.ssh/$REMOTE_KEY_NAME"; then
    echo "Error: Failed to copy SSH key to remote server"
    exit 1
fi
ssh -i "$SSH_KEY" "$SSH_TARGET" "chmod 600 ~/.ssh/$REMOTE_KEY_NAME && rm -f '$TEMP_FILE'"
echo "SSH key copied as ~/.ssh/$REMOTE_KEY_NAME"

echo "Step 5: Installing dependencies on remote server..."

# Check if user has sudo privileges and if passwordless sudo is configured
echo "Checking sudo access on remote server..."
if ssh -i "$SSH_KEY" "$SSH_TARGET" "sudo -n true 2>/dev/null"; then
    echo "Passwordless sudo is available"
    SUDO_CMD="sudo"
elif ssh -i "$SSH_KEY" "$SSH_TARGET" "groups | grep -q sudo"; then
    echo "User has sudo privileges but requires password. You'll be prompted for password during installation."
    SUDO_CMD="sudo"
else
    echo "User doesn't have sudo privileges. Attempting installation without sudo (some steps may fail)..."
    SUDO_CMD=""
fi

# Create the remote commands with password support
if [ -n "$SUDO_PASS" ] && [ "$SUDO_CMD" = "sudo" ]; then
    # Use password for sudo commands via a secure method
    ssh -i "$SSH_KEY" "$SSH_TARGET" << EOF
    set -e
    
    # Create a secure temporary file for the password
    PASS_FILE=\$(mktemp)
    echo '$SUDO_PASS' > "\$PASS_FILE"
    chmod 600 "\$PASS_FILE"
    
    echo "Updating package manager..."
    if command -v apt-get &> /dev/null; then
        sudo -S apt-get update < "\$PASS_FILE"
    elif command -v yum &> /dev/null; then
        sudo -S yum update -y < "\$PASS_FILE"
    elif command -v dnf &> /dev/null; then
        sudo -S dnf update -y < "\$PASS_FILE"
    fi
    
    echo "Installing required dependencies..."
    if command -v apt-get &> /dev/null; then
        sudo -S apt-get install -y curl wget git < "\$PASS_FILE"
    elif command -v yum &> /dev/null; then
        sudo -S yum install -y curl wget git < "\$PASS_FILE"
    elif command -v dnf &> /dev/null; then
        sudo -S dnf install -y curl wget git < "\$PASS_FILE"
    fi
    
    # Clean up password file securely
    shred -u "\$PASS_FILE" 2>/dev/null || rm -f "\$PASS_FILE"
EOF
else
    # Regular sudo or no sudo
    ssh -i "$SSH_KEY" "$SSH_TARGET" << EOF
    set -e
    
    echo "Updating package manager..."
    if command -v apt-get &> /dev/null && [ -n "$SUDO_CMD" ]; then
        $SUDO_CMD apt-get update
    elif command -v yum &> /dev/null && [ -n "$SUDO_CMD" ]; then
        $SUDO_CMD yum update -y
    elif command -v dnf &> /dev/null && [ -n "$SUDO_CMD" ]; then
        $SUDO_CMD dnf update -y
    else
        echo "Skipping package manager update (no sudo access or unsupported package manager)"
    fi
    
    echo "Installing required dependencies..."
    if command -v apt-get &> /dev/null && [ -n "$SUDO_CMD" ]; then
        $SUDO_CMD apt-get install -y curl wget git
    elif command -v yum &> /dev/null && [ -n "$SUDO_CMD" ]; then
        $SUDO_CMD yum install -y curl wget git
    elif command -v dnf &> /dev/null && [ -n "$SUDO_CMD" ]; then
        $SUDO_CMD dnf install -y curl wget git
    else
        echo "Skipping dependency installation (no sudo access). Ensure curl, wget, and git are available."
    fi
EOF
fi

ssh -i "$SSH_KEY" "$SSH_TARGET" << 'EOF'
    
    echo "Setting up repository in ~/repos..."
    mkdir -p ~/repos
    cd ~/repos
    
    if [ -d "quickStart" ]; then
        echo "quickStart directory already exists"
        if [ -d "quickStart/.git" ]; then
            echo "Existing quickStart is a git repository, pulling latest changes..."
            cd quickStart
            if ! git pull origin master 2>/dev/null && ! git pull origin main 2>/dev/null; then
                echo "Warning: Git pull failed, but continuing with existing repository"
            fi
        else
            echo "Existing quickStart is not a git repository, backing up and cloning fresh..."
            mv quickStart quickStart.backup.$(date +%Y%m%d_%H%M%S)
            REPO_URL="${REPO_URL:-git@github.com:antoszy/quickStart.git}"
            if ! git clone "$REPO_URL"; then
                echo "Error: Failed to clone repository"
                exit 1
            fi
            echo "Repository cloned to ~/repos/quickStart (backup created)"
        fi
    else
        echo "Cloning repository..."
        REPO_URL="${REPO_URL:-git@github.com:antoszy/quickStart.git}"
        if ! git clone "$REPO_URL"; then
            echo "Error: Failed to clone repository"
            exit 1
        fi
        echo "Repository cloned to ~/repos/quickStart"
    fi
EOF

echo "Remote setup completed successfully!"
echo "You can now SSH to $SSH_TARGET without a password and the repository is cloned to ~/repos/quickStart"
echo ""
echo "To access your repository on the remote server:"
echo "1. SSH to the server: ssh $SSH_TARGET"
echo "2. Navigate to your project: cd ~/repos/quickStart"