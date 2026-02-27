#!/bin/bash

# EL-Modras Deployment Script
# Deploys the backend to Google Cloud Run

set -e

# Configuration
PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-el-modras}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="el-modras-backend"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "🚀 Deploying EL-Modras Backend to Cloud Run"
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Service: ${SERVICE_NAME}"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please install Google Cloud SDK."
    exit 1
fi

# Set project
echo "📋 Setting project..."
gcloud config set project ${PROJECT_ID}

# Enable required APIs
echo "🔧 Enabling required APIs..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    secretmanager.googleapis.com \
    firestore.googleapis.com \
    aiplatform.googleapis.com

# Build and push Docker image
echo "🏗️ Building Docker image..."
cd "$(dirname "$0")/.."
gcloud builds submit --tag ${IMAGE_NAME}

# Deploy to Cloud Run
echo "☁️ Deploying to Cloud Run..."
gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME} \
    --platform managed \
    --region ${REGION} \
    --allow-unauthenticated \
    --memory 1Gi \
    --cpu 1 \
    --min-instances 0 \
    --max-instances 10 \
    --timeout 300 \
    --set-env-vars "ENVIRONMENT=production,GOOGLE_CLOUD_PROJECT=${PROJECT_ID}" \
    --set-secrets "GEMINI_API_KEY=gemini-api-key:latest"

# Get service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
    --platform managed \
    --region ${REGION} \
    --format 'value(status.url)')

echo ""
echo "✅ Deployment complete!"
echo "🌐 Service URL: ${SERVICE_URL}"
echo ""
echo "Next steps:"
echo "1. Update iOS app's AppConfig.swift with the service URL"
echo "2. Test the endpoints:"
echo "   curl ${SERVICE_URL}/health"
echo "   curl ${SERVICE_URL}/"
