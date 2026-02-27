# 🚀 EL-Modras Backend Deployment Guide

## Step-by-Step Instructions (For Beginners)

### Step 1: Get a Google Cloud Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Sign in with your Google account
3. If new, you get **$300 free credits** for 90 days!

---

### Step 2: Create a New Project

1. Click the project dropdown at the top (next to "Google Cloud")
2. Click **"New Project"**
3. Name it: `el-modras`
4. Click **Create**
5. Wait for it to be created, then select it

---

### Step 3: Get Your Gemini API Key

1. Go to [Google AI Studio](https://aistudio.google.com/apikey)
2. Click **"Create API Key"**
3. Select your `el-modras` project
4. **Copy the API key** and save it somewhere safe!

---

### Step 4: Install Google Cloud CLI (One Time)

**On Mac (Terminal):**
```bash
# Install using Homebrew
brew install google-cloud-sdk

# Or download from: https://cloud.google.com/sdk/docs/install
```

After installing, restart your terminal.

---

### Step 5: Login to Google Cloud

Open Terminal and run:
```bash
# Login to your Google account
gcloud auth login

# Set your project
gcloud config set project el-modras
```

A browser window will open - login with your Google account.

---

### Step 6: Enable Required APIs

Run this command:
```bash
gcloud services enable \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    aiplatform.googleapis.com
```

---

### Step 7: Store Your API Key Securely

```bash
# Create a secret for your Gemini API key
# Replace YOUR_API_KEY with your actual key from Step 3
echo -n "YOUR_API_KEY" | gcloud secrets create gemini-api-key --data-file=-
```

---

### Step 8: Deploy the Backend

Navigate to your project folder and run:
```bash
cd /Users/taher/Documents/EL-Modras/Backend

# Build and deploy (this takes 2-5 minutes)
gcloud run deploy el-modras-backend \
    --source . \
    --region us-central1 \
    --allow-unauthenticated \
    --set-secrets GEMINI_API_KEY=gemini-api-key:latest \
    --set-env-vars ENVIRONMENT=production
```

When asked:
- "Allow unauthenticated invocations?" → Type **y** and press Enter

---

### Step 9: Get Your Backend URL

After deployment, you'll see something like:
```
Service URL: https://el-modras-backend-xxxxx-uc.a.run.app
```

**Copy this URL!** You'll need it for the iOS app.

---

### Step 10: Update iOS App with Backend URL

Open Xcode and edit `Core/Network/AppConfig.swift`:

```swift
static var backendURL: String {
    return "https://el-modras-backend-xxxxx-uc.a.run.app"  // Your URL here
}
```

---

## ✅ Done! Your backend is now live on Google Cloud!

---

## 🔧 Useful Commands

```bash
# Check deployment status
gcloud run services describe el-modras-backend --region us-central1

# View logs
gcloud run services logs read el-modras-backend --region us-central1

# Update deployment (after code changes)
gcloud run deploy el-modras-backend --source . --region us-central1

# Delete everything (if needed)
gcloud run services delete el-modras-backend --region us-central1
```

---

## 💰 Cost

- **Cloud Run**: Free tier includes 2 million requests/month
- **Gemini API**: Free tier includes generous usage
- **Total for hackathon**: Likely **$0** if within free tiers

---

## ❓ Common Issues

### "Permission denied"
```bash
gcloud auth login
gcloud config set project el-modras
```

### "API not enabled"
```bash
gcloud services enable run.googleapis.com cloudbuild.googleapis.com
```

### "Secret not found"
```bash
echo -n "YOUR_API_KEY" | gcloud secrets create gemini-api-key --data-file=-
```

---

## 📱 Testing Your Backend

Open in browser:
```
https://YOUR-URL.run.app/
```

You should see:
```json
{
    "name": "EL-Modras API",
    "version": "1.0.0",
    "status": "running"
}
```

Health check:
```
https://YOUR-URL.run.app/health
```
