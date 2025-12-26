#!/bin/bash

# Script to push ANITA project to GitHub
# Usage: ./push_to_github.sh YOUR_GITHUB_USERNAME REPO_NAME

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ./push_to_github.sh YOUR_GITHUB_USERNAME REPO_NAME"
    echo "Example: ./push_to_github.sh mishadzhuran anita"
    exit 1
fi

GITHUB_USER=$1
REPO_NAME=$2

cd "/Users/mishadzhuran/My projects"

# Check if remote already exists
if git remote get-url origin &>/dev/null; then
    echo "Remote 'origin' already exists. Removing it..."
    git remote remove origin
fi

# Add remote
echo "Adding remote repository..."
git remote add origin "https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

# Ensure we're on main branch
git branch -M main

# Push to GitHub
echo "Pushing to GitHub..."
git push -u origin main

if [ $? -eq 0 ]; then
    echo "✅ Successfully pushed to GitHub!"
    echo "Repository: https://github.com/${GITHUB_USER}/${REPO_NAME}"
else
    echo "❌ Failed to push. Please check:"
    echo "1. Repository exists on GitHub: https://github.com/${GITHUB_USER}/${REPO_NAME}"
    echo "2. You have push access"
    echo "3. Your GitHub credentials are configured"
fi

