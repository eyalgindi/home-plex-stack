#!/bin/bash

# ============================================================================
# GitHub MCP Server Test Script
# ============================================================================
# This script helps verify GitHub MCP server configuration
# ============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=== GitHub MCP Server Test ==="
echo

# Check for MCP config file
print_info "Checking for MCP configuration file..."
MCP_CONFIG=""
if [ -f ~/.cursor/mcp.json ]; then
    MCP_CONFIG=~/.cursor/mcp.json
    print_success "Found: ~/.cursor/mcp.json"
elif [ -f ~/.config/cursor/mcp.json ]; then
    MCP_CONFIG=~/.config/cursor/mcp.json
    print_success "Found: ~/.config/cursor/mcp.json"
else
    print_warning "MCP config file not found in standard locations"
    echo "  Expected locations:"
    echo "    - ~/.cursor/mcp.json"
    echo "    - ~/.config/cursor/mcp.json"
fi

if [ -n "$MCP_CONFIG" ]; then
    echo
    print_info "MCP Configuration:"
    if grep -q "github" "$MCP_CONFIG" 2>/dev/null; then
        print_success "GitHub MCP server found in configuration"
        echo
        echo "GitHub server configuration:"
        python3 -m json.tool "$MCP_CONFIG" 2>/dev/null | grep -A 10 "github" || cat "$MCP_CONFIG" | grep -A 10 "github"
    else
        print_warning "GitHub MCP server not found in configuration"
        echo
        echo "To add GitHub MCP server, add this to $MCP_CONFIG:"
        echo
        cat << 'EOF'
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your_token_here"
      }
    }
  }
}
EOF
    fi
fi

echo
print_info "Testing GitHub API access (using GitHub CLI)..."
if command -v gh &> /dev/null; then
    if gh auth status &>/dev/null; then
        print_success "GitHub CLI is authenticated"
        echo
        print_info "Testing API access:"
        USER_INFO=$(gh api user 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(f\"User: {d.get('login', 'unknown')}\")" 2>/dev/null || echo "User: (checking...)")
        echo "  $USER_INFO"
        echo
        print_info "Repositories:"
        gh repo list --limit 3 2>/dev/null | head -3 || echo "  (Unable to list repositories)"
    else
        print_warning "GitHub CLI not authenticated"
        echo "  Run: gh auth login"
    fi
else
    print_warning "GitHub CLI (gh) not installed"
    echo "  Install: https://cli.github.com/"
fi

echo
print_info "Testing MCP Server Package Availability..."
if command -v npx &> /dev/null; then
    print_success "npx is available"
    echo
    print_info "Checking if GitHub MCP server package is accessible..."
    if npx -y @modelcontextprotocol/server-github --help &>/dev/null; then
        print_success "GitHub MCP server package is accessible"
    else
        print_info "Package check: (This is normal, package will be downloaded when needed)"
    fi
else
    print_warning "npx not found"
    echo "  npx is required to run MCP servers"
    echo "  Install Node.js: https://nodejs.org/"
fi

echo
print_info "=== Testing Instructions ==="
echo
echo "To test GitHub MCP server in Cursor:"
echo
echo "1. Ensure MCP is configured (see above)"
echo "2. Restart Cursor completely"
echo "3. Open AI Chat: Cmd+L (Mac) or Ctrl+L (Windows/Linux)"
echo "4. Try these test prompts:"
echo
echo "   Test 1: List repositories"
echo "   → 'Use the GitHub tool to list my repositories'"
echo
echo "   Test 2: Get repository info"
echo "   → 'Show me information about the home-plex-stack repository'"
echo
echo "   Test 3: Check recent commits"
echo "   → 'What are the latest commits in eyalgindi/home-plex-stack?'"
echo
echo "   Test 4: Repository details"
echo "   → 'Get details for the home-plex-stack repository'"
echo
echo "5. Verify MCP is working:"
echo "   - Cursor should recognize and use the GitHub tool"
echo "   - You should see GitHub API responses"
echo "   - Check Cursor's status bar for MCP indicators"
echo



