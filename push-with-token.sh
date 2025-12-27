#!/bin/bash

# ============================================================================
# Push to GitHub using provided token
# ============================================================================

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

GITHUB_USER="eyalgindi"
REPO_NAME="home-plex-stack"
GH_TOKEN="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"

export GH_TOKEN

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

print_info "GitHub Push Script"
echo

# Check if repo exists
if gh repo view "${GITHUB_USER}/${REPO_NAME}" &>/dev/null; then
    print_success "Repository exists: ${GITHUB_USER}/${REPO_NAME}"
else
    print_warning "Repository does not exist yet"
    echo
    print_info "Please create the repository manually:"
    echo "  1. Go to: https://github.com/new"
    echo "  2. Repository name: ${REPO_NAME}"
    echo "  3. Description: Home Plex Entertainment Stack - Docker Compose setup"
    echo "  4. Visibility: Private"
    echo "  5. DO NOT initialize with README, .gitignore, or license"
    echo "  6. Click 'Create repository'"
    echo
    read -p "Press Enter after you've created the repository..."
    
    # Verify it exists now
    if ! gh repo view "${GITHUB_USER}/${REPO_NAME}" &>/dev/null; then
        print_error "Repository still not found. Please create it first."
        exit 1
    fi
fi

# Configure remote
REPO_URL="https://${GH_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"

if git remote -v | grep -q origin; then
    CURRENT_REMOTE=$(git remote get-url origin | sed "s|https://[^@]*@|https://|")
    if [ "$CURRENT_REMOTE" != "https://github.com/${GITHUB_USER}/${REPO_NAME}.git" ]; then
        print_info "Updating remote URL..."
        git remote set-url origin "$REPO_URL"
    else
        git remote set-url origin "$REPO_URL"
    fi
else
    print_info "Adding remote 'origin'..."
    git remote add origin "$REPO_URL"
fi

print_success "Remote configured"

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
print_info "Current branch: $CURRENT_BRANCH"

# Push to GitHub
echo
print_info "Pushing to GitHub..."
if git push -u origin "$CURRENT_BRANCH"; then
    print_success "Repository pushed to GitHub!"
    echo
    print_info "Repository URL: https://github.com/${GITHUB_USER}/${REPO_NAME}"
    print_info "View at: https://github.com/${GITHUB_USER}/${REPO_NAME}"
else
    print_error "Push failed"
    exit 1
fi

