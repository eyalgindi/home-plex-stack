#!/bin/bash

# ============================================================================
# Push to GitHub Script
# ============================================================================
# Quick script to push home_plex to GitHub
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

GITHUB_USER="eyalgindi"
REPO_NAME="home-plex-stack"
REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

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

print_info "GitHub Repository Push Script"
echo
print_info "Repository: ${REPO_URL}"
echo

# Check if remote exists
if git remote -v | grep -q origin; then
    CURRENT_REMOTE=$(git remote get-url origin)
    if [ "$CURRENT_REMOTE" != "$REPO_URL" ]; then
        print_warning "Remote 'origin' points to different URL:"
        echo "  Current: $CURRENT_REMOTE"
        echo "  Target:  $REPO_URL"
        read -p "Update remote? (y/N): " update
        if [[ "$update" =~ ^[Yy]$ ]]; then
            git remote set-url origin "$REPO_URL"
            print_success "Remote updated"
        else
            print_info "Using existing remote: $CURRENT_REMOTE"
            REPO_URL="$CURRENT_REMOTE"
        fi
    else
        print_success "Remote already configured correctly"
    fi
else
    print_info "Adding remote 'origin'..."
    git remote add origin "$REPO_URL"
    print_success "Remote added"
fi

echo
print_info "IMPORTANT: Create the repository on GitHub first!"
echo
print_info "Steps:"
echo "  1. Go to: https://github.com/new"
echo "  2. Repository name: ${REPO_NAME}"
echo "  3. Description: Home Plex Entertainment Stack - Docker Compose setup"
echo "  4. Visibility: Private"
echo "  5. DO NOT initialize with README, .gitignore, or license"
echo "  6. Click 'Create repository'"
echo
read -p "Press Enter after you've created the repository on GitHub..."

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
print_info "Current branch: $CURRENT_BRANCH"

# Push to GitHub
echo
print_info "Pushing to GitHub..."
print_warning "You will be prompted for credentials:"
echo "  Username: ${GITHUB_USER}"
echo "  Password: Use a Personal Access Token (not your password)"
echo "  Create token: https://github.com/settings/tokens"
echo "  Required scope: repo"
echo

read -p "Ready to push? (Y/n): " push
if [[ "$push" =~ ^[Nn]$ ]]; then
    print_info "Push cancelled. Run this script again when ready."
    exit 0
fi

print_info "Pushing ${CURRENT_BRANCH} branch to GitHub..."
if git push -u origin "$CURRENT_BRANCH"; then
    print_success "Repository pushed to GitHub!"
    echo
    print_info "Repository URL: https://github.com/${GITHUB_USER}/${REPO_NAME}"
    print_info "View at: ${REPO_URL}"
else
    print_error "Push failed. Common issues:"
    echo "  1. Repository doesn't exist on GitHub - create it first"
    echo "  2. Authentication failed - use Personal Access Token"
    echo "  3. Network issues - check internet connection"
    echo
    print_info "To retry, run: git push -u origin $CURRENT_BRANCH"
    exit 1
fi

