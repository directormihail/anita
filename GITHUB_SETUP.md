# GitHub Repository Setup Guide

Your local repository is ready! Follow these steps to create the GitHub repository and push your code.

## Step 1: Create GitHub Repository

1. Go to [GitHub.com](https://github.com) and sign in
2. Click the **+** icon in the top right corner
3. Select **New repository**
4. Fill in the repository details:
   - **Repository name**: `anita` (or your preferred name)
   - **Description**: "ANITA - AI Financial Assistant (Backend & iOS)"
   - **Visibility**: Choose Public or Private
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)
5. Click **Create repository**

## Step 2: Connect and Push to GitHub

After creating the repository, GitHub will show you commands. Use these commands in your terminal:

```bash
cd "/Users/mishadzhuran/My projects"

# Add the remote repository (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/anita.git

# Or if you prefer SSH:
# git remote add origin git@github.com:YOUR_USERNAME/anita.git

# Rename branch to main if needed (GitHub uses 'main' by default)
git branch -M main

# Push your code to GitHub
git push -u origin main
```

## Alternative: Using GitHub CLI

If you have GitHub CLI installed:

```bash
cd "/Users/mishadzhuran/My projects"
gh repo create anita --public --source=. --remote=origin --push
```

## Step 3: Verify

1. Go to your GitHub repository page
2. You should see all your files:
   - `ANITA backend/`
   - `ANITA IOS/`
   - `README.md`
   - `.gitignore`

## Next Steps

- Add collaborators in repository settings
- Set up branch protection rules if needed
- Configure GitHub Actions for CI/CD (optional)
- Add repository topics/tags for discoverability

## Troubleshooting

### Authentication Issues
If you get authentication errors:
- Use a Personal Access Token instead of password
- Or set up SSH keys for GitHub

### Branch Name
If your branch is named `master` instead of `main`:
```bash
git branch -M main
git push -u origin main
```

### Already Have a Remote?
If you get "remote origin already exists":
```bash
git remote remove origin
git remote add origin https://github.com/YOUR_USERNAME/anita.git
```

