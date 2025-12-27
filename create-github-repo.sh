#!/bin/bash

# ============================================================================
# Create GitHub Repository Script
# ============================================================================
# Uses GitHub CLI to create private repo and push code
# ============================================================================

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

GITHUB_USER="eyalgindi"
REPO_NAME="home-plex-stack"

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

print_info "GitHub Repository Creation Script"
echo

# Check authentication
if ! gh auth status &>/dev/null; then
    print_warning "GitHub CLI not authenticated"
    echo
    print_info "Authentication Options:"
    echo "  1. Interactive login (recommended)"
    echo "  2. Use Personal Access Token"
    echo
    read -p "Choose option (1/2): " auth_option
    
    if [ "$auth_option" = "2" ]; then
        read -sp "Enter your GitHub Personal Access Token: " GITHUB_TOKEN
        echo
        export GH_TOKEN="$GITHUB_TOKEN"
        print_info "Token set. Verifying..."
        if gh auth status &>/dev/null; then
            print_success "Authentication successful"
        else
            print_error "Authentication failed. Please check your token."
            exit 1
        fi
    else
        print_info "Starting interactive authentication..."
        print_info "Follow the prompts in your browser..."
        gh auth login
    fi
else
    print_success "Already authenticated"
    gh auth status
fi

echo

# Check if repo already exists
if gh repo view "${GITHUB_USER}/${REPO_NAME}" &>/dev/null; then
    print_warning "Repository already exists: ${GITHUB_USER}/${REPO_NAME}"
    read -p "Do you want to push to existing repo? (y/N): " push_existing
    if [[ "$push_existing" =~ ^[Yy]$ ]]; then
        # Set remote if not exists
        if ! git remote -v | grep -q origin; then
            git remote add origin "https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
        fi
        CURRENT_BRANCH=$(git branch --show-current)
        print_info "Pushing to existing repository..."
        git push -u origin "$CURRENT_BRANCH"
        print_success "Code pushed to existing repository!"
        exit 0
    else
        print_info "Exiting. Repository exists at: https://github.com/${GITHUB_USER}/${REPO_NAME}"
        exit 0
    fi
fi

# Create repository
print_info "Creating private repository: ${REPO_NAME}"
echo

if gh repo create "$REPO_NAME" \
    --private \
    --description "Home Plex Entertainment Stack - Docker Compose setup for automated media management" \
    --source=. \
    --remote=origin \
    --push; then
    print_success "Repository created and code pushed!"
    echo
    print_info "Repository URL: https://github.com/${GITHUB_USER}/${REPO_NAME}"
    print_info "View at: https://github.com/${GITHUB_USER}/${REPO_NAME}"
else
    print_error "Failed to create repository"
    exit 1
fi

