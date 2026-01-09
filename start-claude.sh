#!/bin/bash
# Wrapper script to start Claude with proper terminal settings

# Initialize firewall
sudo /usr/local/bin/init-firewall.sh

# Start Claude Code
exec claude --dangerously-skip-permissions
