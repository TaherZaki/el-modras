#!/bin/bash

# ===========================================
# EL-Modras Easy Deploy Script
# Run this after setting up gcloud CLI
# ===========================================

echo ""
echo "🎓 EL-Modras Backend Deployment"
echo "================================"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Error: gcloud CLI not installed"
    echo ""
    echo "Install it with: brew install google-cloud-sdk"
    echo "Or download from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if logged in
ACCOUNT=$(gcloud config get-value account 2>/dev/null)
if [ -z "$ACCOUNT" ]; then
    echo "❌ Not logged in to Google Cloud"
    echo ""
    echo "Run: gcloud auth login"
    exit 1
fi

echo "✅ Logged in as: $ACCOUNT"

# Get project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo ""
    echo "❌ No project set"
    echo ""
    read -p "Enter your Google Cloud Project ID: " PROJECT_ID
    gcloud config set project $PROJECT_ID
fi

echo "✅ Project: $PROJECT_ID"
echo ""

# Check for API key
if ! gcloud secrets describe gemini-api-key &>/dev/null 2>&1; then
    echo "⚠️  Gemini API key not found in Secret Manager"
    echo ""
    echo "Get your API key from: https://aistudio.google.com/apikey"
    echo ""
    read -p "Enter your Gemini API Key: " API_KEY
    
    if [ -z "$API_KEY" ]; then
        echo "❌ API key is required"
        exit 1
    fi
    
    echo ""
    echo "📝 Storing API key in Secret Manager..."
    echo -n "$API_KEY" | gcloud secrets create gemini-api-key --data-file=-
    echo "✅ API key stored securely"
fi

echo ""
echo "🔧 Enabling required APIs..."
gcloud services enable \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    2>/dev/null

echo "✅ APIs enabled"
echo ""

# Deploy
echo "🚀 Deploying to Cloud Run..."
echo "   (This may take 2-5 minutes)"
echo ""

cd "$(dirname "$0")/.."

gcloud run deploy el-modras-backend \
    --source . \
    --region us-central1 \
    --allow-unauthenticated \
    --memory 1Gi \
    --timeout 300 \
    --set-secrets GEMINI_API_KEY=gemini-api-key:latest \
    --set-env-vars "ENVIRONMENT=production,GOOGLE_CLOUD_PROJECT=$PROJECT_ID" \
    --quiet

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    
    # Get service URL
    SERVICE_URL=$(gcloud run services describe el-modras-backend \
        --region us-central1 \
        --format 'value(status.url)' 2>/dev/null)
    
    echo "================================"
    echo "🌐 Your Backend URL:"
    echo ""
    echo "   $SERVICE_URL"
    echo ""
    echo "================================"
    echo ""
    echo "📱 Next steps:"
    echo "1. Copy the URL above"
    echo "2. Open Xcode"
    echo "3. Edit: Core/Network/AppConfig.swift"
    echo "4. Replace backendURL with your URL"
    echo ""
    echo "🧪 Test your backend:"
    echo "   curl $SERVICE_URL/health"
    echo ""
else
    echo ""
    echo "❌ Deployment failed. Check the errors above."
    exit 1
fi
