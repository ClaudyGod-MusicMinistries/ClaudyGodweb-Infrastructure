# 🔧 Quick Fix: Image Name Mismatch

## Problem
```
Error: manifest unknown
Image ghcr.io/claudygod-musicministries/website2.0:latest
```

Your VPS `.env` has the wrong image name.

## Solution

### Option 1: Fix via SSH (Recommended)

```bash
# SSH into your VPS
ssh server@207.180.253.39

# Navigate to deployment directory
cd ~/apps/claudygod/ClaudyGodweb-Infrastructure

# Fix the image names in .env
sed -i 's|ghcr.io/claudygod-musicministries/website2.0:|ghcr.io/claudygod-musicministries/cgm-web:|g' .env

# Verify the fix
grep "FRONTEND_IMAGE\|BACKEND_IMAGE" .env
```

**Expected output:**
```
BACKEND_IMAGE=ghcr.io/claudygod-musicministries/cgm-api:latest
FRONTEND_IMAGE=ghcr.io/claudygod-musicministries/cgm-web:latest
```

### Option 2: Manual Edit

```bash
# On VPS
nano ~/apps/claudygod/ClaudyGodweb-Infrastructure/.env

# Find these lines and update them:
# Change FROM:
FRONTEND_IMAGE=ghcr.io/claudygod-musicministries/website2.0:latest

# Change TO:
FRONTEND_IMAGE=ghcr.io/claudygod-musicministries/cgm-web:latest

# Save and exit (Ctrl+X, then Y, then Enter)
```

## Correct Image Names

The GitHub Actions workflows build with these **exact** names:

| Component | Correct Image Name |
|---|---|
| Frontend (Next.js) | `ghcr.io/claudygod-musicministries/cgm-web` |
| Backend (.NET) | `ghcr.io/claudygod-musicministries/cgm-api` |

These names come from:
- `website2.0/.github/workflows/deploy-production.yml` — builds `cgm-web`
- Infrastructure repo — uses these names

## After Fixing

```bash
# On VPS, verify the fix
grep FRONTEND_IMAGE .env
# Should show: ghcr.io/claudygod-musicministries/cgm-web:latest

# Redeploy
make deploy

# Check status
make ps
```

## Why This Happened

- Repository names: `website2.0`, `cgm-api`
- Docker image names: `cgm-web`, `cgm-api` (different naming convention)
- The `.env.example` has the correct names, but if `.env` was copied from an old version, it might have the wrong names

**Fix your VPS `.env` now and deployment will proceed!** ✅
