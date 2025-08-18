#!/bin/bash

set -e

echo "Claude Code Installation Script"
echo "==============================="

# Check if running as root (not recommended)
if [ "$EUID" -eq 0 ]; then
    echo "Warning: Running as root is not recommended for Claude Code installation"
    echo "Consider running as a regular user instead"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Step 1: Checking system requirements..."

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "Node.js not found. Installing Node.js..."
    
    # Detect package manager and install Node.js 20+
    if command -v apt-get &> /dev/null; then
        echo "Installing Node.js 20 via NodeSource repository..."
        # Remove old Node.js versions first
        sudo apt-get remove -y nodejs npm || true
        sudo apt-get autoremove -y || true
        
        # Install Node.js 20 from NodeSource
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v yum &> /dev/null; then
        echo "Installing Node.js 20 via NodeSource repository..."
        # Remove old versions
        sudo yum remove -y nodejs npm || true
        
        # Install Node.js 20 from NodeSource
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo yum install -y nodejs
    elif command -v dnf &> /dev/null; then
        echo "Installing Node.js 20 via NodeSource repository..."
        # Remove old versions
        sudo dnf remove -y nodejs npm || true
        
        # Install Node.js 20 from NodeSource
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo dnf install -y nodejs
    elif command -v brew &> /dev/null; then
        echo "Using Homebrew to install Node.js..."
        # Uninstall old version if present
        brew uninstall node || true
        brew install node
    else
        echo "Error: No supported package manager found (apt-get, yum, dnf, brew)"
        echo "Please install Node.js 18+ manually from https://nodejs.org/"
        exit 1
    fi
else
    echo "Node.js found: $(node --version)"
fi

# Check Node.js version (requires 18+)
NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "Found Node.js version $NODE_VERSION, but Claude Code requires Node.js 18 or higher"
    echo "Upgrading Node.js to version 20..."
    
    # Upgrade Node.js using the same logic as installation
    if command -v apt-get &> /dev/null; then
        echo "Upgrading Node.js 20 via NodeSource repository..."
        # Remove old Node.js versions first
        sudo apt-get remove -y nodejs npm || true
        sudo apt-get autoremove -y || true
        
        # Install Node.js 20 from NodeSource
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v yum &> /dev/null; then
        echo "Upgrading Node.js 20 via NodeSource repository..."
        # Remove old versions
        sudo yum remove -y nodejs npm || true
        
        # Install Node.js 20 from NodeSource
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo yum install -y nodejs
    elif command -v dnf &> /dev/null; then
        echo "Upgrading Node.js 20 via NodeSource repository..."
        # Remove old versions
        sudo dnf remove -y nodejs npm || true
        
        # Install Node.js 20 from NodeSource
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo dnf install -y nodejs
    elif command -v brew &> /dev/null; then
        echo "Using Homebrew to upgrade Node.js..."
        brew upgrade node || brew install node
    else
        echo "Error: Cannot upgrade Node.js automatically"
        echo "Please upgrade Node.js manually:"
        echo "- Visit https://nodejs.org/ for latest version"
        echo "- Or use a Node version manager like nvm"
        exit 1
    fi
    
    # Verify the upgrade worked
    NEW_NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NEW_NODE_VERSION" -lt 18 ]; then
        echo "Error: Node.js upgrade failed. Still at version $NEW_NODE_VERSION"
        echo "Please install Node.js 18+ manually from https://nodejs.org/"
        exit 1
    fi
    echo "✅ Node.js upgraded to version $(node --version)"
fi

echo "✅ Node.js version $(node --version) is compatible"

echo "Step 2: Checking npm availability..."

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo "npm not found. Attempting to install npm..."
    
    # Try to install npm via package manager
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y npm || echo "npm installation via apt-get failed"
    elif command -v yum &> /dev/null; then
        sudo yum install -y npm || echo "npm installation via yum failed"
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y npm || echo "npm installation via dnf failed"
    fi
    
    # If still not available, try corepack
    if ! command -v npm &> /dev/null; then
        echo "Trying to enable npm via corepack..."
        if command -v corepack &> /dev/null; then
            corepack enable npm
        else
            echo "Error: npm not available and no alternative installation method found"
            echo "Please install npm manually or use a Node.js installation that includes npm"
            exit 1
        fi
    fi
fi

# Verify npm is working
if ! npm --version &> /dev/null; then
    echo "Error: npm is installed but not working correctly"
    echo "Try running: npm doctor"
    exit 1
fi

echo "✅ npm version $(npm --version) is available"

echo "Step 3: Installing Claude Code..."

# Check npm global directory permissions
NPM_PREFIX=$(npm config get prefix)
echo "npm global directory: $NPM_PREFIX"

if [ ! -w "$NPM_PREFIX" ] && [ "$NPM_PREFIX" != "$HOME/.local" ]; then
    echo "⚠️  Global npm directory requires elevated permissions"
    echo ""
    echo "Choose installation method:"
    echo "1. Install globally with sudo (may cause permission issues later)"
    echo "2. Install to user directory (recommended)"
    echo "3. Exit and configure npm properly"
    echo ""
    read -p "Enter choice (1/2/3): " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            echo "Installing with sudo..."
            if ! sudo npm install -g @anthropic-ai/claude-code; then
                echo "Error: Failed to install Claude Code with sudo"
                exit 1
            fi
            ;;
        2)
            echo "Setting up user directory installation..."
            mkdir -p ~/.local/bin
            npm config set prefix ~/.local
            
            # Add to PATH if not already there
            if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
                echo "Adding ~/.local/bin to PATH..."
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
                echo "⚠️  Please run: source ~/.bashrc or restart your terminal after installation"
            fi
            
            echo "Installing to user directory..."
            if ! npm install -g @anthropic-ai/claude-code; then
                echo "Error: Failed to install Claude Code to user directory"
                exit 1
            fi
            ;;
        3)
            echo "Installation cancelled. To fix npm permissions:"
            echo "1. Use a Node version manager like nvm: https://github.com/nvm-sh/nvm"
            echo "2. Or change npm global directory: npm config set prefix ~/.local"
            echo "3. Or fix npm permissions: https://docs.npmjs.com/resolving-eacces-permissions-errors-when-installing-packages-globally"
            exit 1
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
else
    # Install normally if we have permissions
    echo "Installing @anthropic-ai/claude-code globally..."
    if ! npm install -g @anthropic-ai/claude-code; then
        echo "Error: Failed to install Claude Code via npm"
        echo ""
        echo "Troubleshooting tips:"
        echo "1. Check if you have write permissions to global npm directory"
        echo "2. Try: npm config get prefix"
        echo "3. Consider using a Node version manager (nvm)"
        echo "4. Or install without sudo using: npm config set prefix ~/.local"
        exit 1
    fi
fi

echo "✅ Claude Code installed successfully!"

echo "Step 4: Verifying installation..."

# Verify Claude Code installation
if command -v claude &> /dev/null; then
    echo "✅ Claude Code is available in PATH"
    echo "Version: $(claude --version 2>/dev/null || echo "Version check failed")"
else
    echo "⚠️  Claude command not found in PATH"
    echo ""
    echo "Troubleshooting:"
    echo "1. Try restarting your terminal"
    echo "2. Or run: source ~/.bashrc (Linux) / source ~/.zshrc (macOS)"
    echo "3. Check npm global bin directory: npm bin -g"
    echo "4. Ensure npm global bin is in your PATH"
    
    # Show PATH info
    NPM_BIN=$(npm bin -g 2>/dev/null || echo "unknown")
    echo "5. npm global bin directory: $NPM_BIN"
    
    if [ "$NPM_BIN" != "unknown" ]; then
        echo "6. Add to PATH if needed: export PATH=\"$NPM_BIN:\$PATH\""
    fi
fi

echo ""
echo "Installation completed!"
echo ""
echo "Next steps:"
echo "1. Open a new terminal or run: source ~/.bashrc"
echo "2. Navigate to your project directory"
echo "3. Run: claude"
echo "4. Follow the authentication prompts to connect your Anthropic account"
echo ""
echo "For help, visit: https://docs.anthropic.com/en/docs/claude-code"