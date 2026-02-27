#!/bin/bash

# EL-Modras Infrastructure Setup Script
# Sets up all required Google Cloud resources

set -e

# Configuration
PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-el-modras}"
REGION="${REGION:-us-central1}"

echo "🏗️ Setting up EL-Modras Infrastructure"
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please install Google Cloud SDK."
    exit 1
fi

# Set project
gcloud config set project ${PROJECT_ID}

# Enable required APIs
echo "🔧 Enabling Google Cloud APIs..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    secretmanager.googleapis.com \
    firestore.googleapis.com \
    aiplatform.googleapis.com \
    storage.googleapis.com

# Create Firestore database (if not exists)
echo "📦 Setting up Firestore..."
gcloud firestore databases create --region=${REGION} 2>/dev/null || echo "Firestore database already exists"

# Create Secret Manager secret for Gemini API key
echo "🔐 Setting up Secret Manager..."
if ! gcloud secrets describe gemini-api-key &>/dev/null; then
    echo "Creating gemini-api-key secret..."
    echo -n "Enter your Gemini API key: "
    read -s GEMINI_API_KEY
    echo
    echo -n "${GEMINI_API_KEY}" | gcloud secrets create gemini-api-key --data-file=-
    echo "Secret created successfully"
else
    echo "Secret gemini-api-key already exists"
fi

# Grant Cloud Run access to Secret Manager
echo "🔑 Configuring IAM permissions..."
PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')
gcloud secrets add-iam-policy-binding gemini-api-key \
    --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor" 2>/dev/null || true

# Create Cloud Storage bucket for assets
BUCKET_NAME="${PROJECT_ID}-assets"
echo "📁 Setting up Cloud Storage..."
gsutil mb -l ${REGION} gs://${BUCKET_NAME} 2>/dev/null || echo "Bucket already exists"

echo ""
echo "✅ Infrastructure setup complete!"
echo ""
echo "Resources created:"
echo "  - Firestore database"
echo "  - Secret Manager secret: gemini-api-key"
echo "  - Cloud Storage bucket: ${BUCKET_NAME}"
echo ""
echo "Next step: Run ./scripts/deploy.sh to deploy the application"
