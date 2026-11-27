#!/usr/bin/env bash
set -e

echo "============================================================"
echo "       AECIP: Automated Cloud Deployment on AWS (EC2)       "
echo "============================================================"

# Check prerequisites
if ! command -v terraform &> /dev/null; then
    echo "ERROR: terraform CLI is not installed or not in PATH."
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "ERROR: aws CLI is not installed or not in PATH."
    exit 1
fi

echo "Verifying AWS authentication..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "ERROR: AWS credentials are not configured or invalid."
    echo "Please run: aws configure"
    exit 1
fi
echo "AWS authenticated successfully!"

echo ""
echo "[Step 1/2] Initializing Terraform..."
cd terraform
terraform init

echo ""
echo "[Step 2/2] Deploying AECIP Cloud Server on AWS (VPC, Security Group, EC2)..."
terraform apply -auto-approve

DASHBOARD_URL=$(terraform output -raw dashboard_url)
API_HEALTH=$(terraform output -raw api_health_endpoint)
SERVER_IP=$(terraform output -raw ec2_public_ip)

echo ""
echo "============================================================"
echo "       AECIP CLOUD DEPLOYMENT SUCCESSFUL!                   "
echo "============================================================"
echo "Server Public IP:         $SERVER_IP"
echo "Live Streamlit Dashboard: $DASHBOARD_URL"
echo "Live Flask API Health:    $API_HEALTH"
echo "============================================================"
echo "Note: Give the server ~1-2 minutes to finish building the Docker containers."
