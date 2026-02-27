# EL-Modras Terraform

This directory contains Terraform configuration for deploying EL-Modras infrastructure to Google Cloud.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0.0
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- A Google Cloud project with billing enabled

## Setup

1. **Authenticate with Google Cloud:**
   ```bash
   gcloud auth application-default login
   ```

2. **Copy and configure variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Build and push Docker image first:**
   ```bash
   cd ../Backend
   gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/el-modras-backend
   ```

4. **Initialize Terraform:**
   ```bash
   terraform init
   ```

5. **Plan the deployment:**
   ```bash
   terraform plan
   ```

6. **Apply the configuration:**
   ```bash
   terraform apply
   ```

## Resources Created

- **Cloud Run Service** - Backend API hosting
- **Secret Manager Secret** - Gemini API key storage
- **Cloud Storage Bucket** - Asset storage
- **Firestore Database** - User progress data
- **IAM Bindings** - Required permissions

## Outputs

After applying, you'll see:
- `backend_url` - The Cloud Run service URL
- `storage_bucket` - The Cloud Storage bucket name
- `project_id` - Your project ID

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Note:** This will delete all data. Make sure to backup important data first.
