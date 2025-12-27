# GitHub Repository Setup Guide

This guide will help you create a private GitHub repository and push the home_plex content to it.

## Quick Setup

### Option 1: Using the Setup Script (Recommended)

```bash
cd /nfs/data/docker/home_plex
./setup-github.sh
```

The script will guide you through:
1. Creating the repository on GitHub
2. Configuring the remote
3. Pushing the code

### Option 2: Manual Setup

#### Step 1: Create Repository on GitHub

1. Go to: https://github.com/new
2. **Repository name**: `home-plex-stack` (or your preferred name)
3. **Description**: `Home Plex Entertainment Stack - Docker Compose setup`
4. **Visibility**: **Private** ⚠️ (Important - contains configuration templates)
5. **DO NOT** check:
   - ❌ Add a README file
   - ❌ Add .gitignore
   - ❌ Choose a license
6. Click **"Create repository"**

#### Step 2: Configure Remote

```bash
cd /nfs/data/docker/home_plex

# Set your GitHub username and repository name
GITHUB_USER="your-username"
REPO_NAME="home-plex-stack"

# Add remote
git remote add origin https://github.com/${GITHUB_USER}/${REPO_NAME}.git

# Verify remote
git remote -v
```

#### Step 3: Push to GitHub

```bash
# Push main branch
git push -u origin main
```

If prompted for credentials:
- **Username**: Your GitHub username
- **Password**: Use a Personal Access Token (not your password)
  - Create token: https://github.com/settings/tokens
  - Scopes needed: `repo` (full control of private repositories)

## Using Personal Access Token

GitHub no longer accepts passwords for git operations. You need a Personal Access Token:

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Name: `home-plex-stack`
4. Expiration: Choose your preference
5. Scopes: Check `repo` (full control of private repositories)
6. Click "Generate token"
7. **Copy the token immediately** (you won't see it again)

When pushing, use:
- **Username**: Your GitHub username
- **Password**: The Personal Access Token

## Verify Push

After pushing, verify on GitHub:

1. Go to: `https://github.com/YOUR_USERNAME/YOUR_REPO_NAME`
2. You should see all files:
   - README.md
   - docker-compose.yml
   - setup.sh
   - env.example
   - All documentation files

## Security Reminders

⚠️ **Important**: 
- The repository is **private** - keep it that way
- `.env` files are gitignored (never committed)
- No secrets are in the repository
- All sensitive values are in `.env` (local only)

## Future Updates

To push updates:

```bash
cd /nfs/data/docker/home_plex

# Stage changes
git add .

# Commit
git commit -m "Description of changes"

# Push
git push origin main
```

## Clone on Another Machine

To use this setup on another machine:

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git
cd YOUR_REPO_NAME

# Run setup
./setup.sh

# Start services
docker compose up -d
```



