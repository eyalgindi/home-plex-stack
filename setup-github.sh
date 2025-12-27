#!/bin/bash

# ============================================================================
# GitHub Repository Setup Script
# ============================================================================
# This script helps set up the GitHub remote and push the repository
# ============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info "GitHub Repository Setup"
echo

# Check if already has remote
if git remote -v | grep -q origin; then
    print_warning "Remote 'origin' already exists:"
    git remote -v
    read -p "Do you want to update it? (y/N): " update
    if [[ ! "$update" =~ ^[Yy]$ ]]; then
        print_info "Keeping existing remote"
        exit 0
    fi
fi

# Get repository name
read -p "Enter GitHub repository name (e.g., home-plex-stack): " REPO_NAME
if [ -z "$REPO_NAME" ]; then
    print_error "Repository name is required"
    exit 1
fi

# Get GitHub username
read -p "Enter your GitHub username: " GITHUB_USER
if [ -z "$GITHUB_USER" ]; then
    print_error "GitHub username is required"
    exit 1
fi

REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

print_info "Repository will be created at: ${REPO_URL}"
echo
print_info "Please create the repository on GitHub first:"
echo "  1. Go to: https://github.com/new"
echo "  2. Repository name: ${REPO_NAME}"
echo "  3. Description: Home Plex Entertainment Stack - Docker Compose setup"
echo "  4. Visibility: Private"
echo "  5. DO NOT initialize with README, .gitignore, or license"
echo "  6. Click 'Create repository'"
echo
read -p "Press Enter after you've created the repository on GitHub..."

# Set remote
print_info "Setting up remote..."
git remote remove origin 2>/dev/null || true
git remote add origin "$REPO_URL"

print_success "Remote configured: ${REPO_URL}"
echo

# Rename branch to main if needed
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" = "master" ]; then
    read -p "Rename branch from 'master' to 'main'? (Y/n): " rename
    if [[ ! "$rename" =~ ^[Nn]$ ]]; then
        git branch -m master main
        print_success "Branch renamed to 'main'"
    fi
fi

# Push to GitHub
print_info "Pushing to GitHub..."
echo
read -p "Ready to push? (Y/n): " push
if [[ "$push" =~ ^[Nn]$ ]]; then
    print_info "Skipping push. You can push later with:"
    echo "  git push -u origin $(git branch --show-current)"
    exit 0
fi

print_info "Pushing code to GitHub..."
git push -u origin $(git branch --show-current)

print_success "Repository pushed to GitHub!"
echo
print_info "Repository URL: https://github.com/${GITHUB_USER}/${REPO_NAME}"
print_info "You can now access it at: ${REPO_URL}"

