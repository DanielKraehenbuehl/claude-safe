#!/bin/bash
# Setup clipboard integration for WSL
# This script creates aliases to use Windows clipboard from inside the container

cat > /home/node/.clipboard-setup.sh << 'EOF'
# WSL Clipboard Integration
# Automatically sourced in .zshrc

# Function to copy to Windows clipboard
copy() {
    if command -v clip.exe &> /dev/null; then
        clip.exe
    elif [ -f "/mnt/c/Windows/System32/clip.exe" ]; then
        /mnt/c/Windows/System32/clip.exe
    else
        echo "⚠️  Windows clipboard not available in container"
        echo "Use mouse selection in Windows Terminal instead"
        return 1
    fi
}

# Function to paste from Windows clipboard
paste() {
    if command -v powershell.exe &> /dev/null; then
        powershell.exe Get-Clipboard | sed 's/\r$//'
    else
        echo "⚠️  Windows clipboard not available in container"
        echo "Use Ctrl+Shift+V in Windows Terminal instead"
        return 1
    fi
}

# Alias for common clipboard commands
alias pbcopy='copy'
alias pbpaste='paste'
alias xclip='copy'

echo "📋 WSL Clipboard helpers loaded:"
echo "  echo 'text' | copy    # Copy to Windows clipboard"
echo "  paste                  # Paste from Windows clipboard"
EOF

chown node:node /home/node/.clipboard-setup.sh
chmod +x /home/node/.clipboard-setup.sh

# Add to .zshrc if not already there
if ! grep -q ".clipboard-setup.sh" /home/node/.zshrc 2>/dev/null; then
    echo "" >> /home/node/.zshrc
    echo "# WSL Clipboard Integration" >> /home/node/.zshrc
    echo "source ~/.clipboard-setup.sh" >> /home/node/.zshrc
fi

echo "✅ WSL Clipboard integration configured"
