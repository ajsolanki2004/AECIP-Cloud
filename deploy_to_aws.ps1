<#
.SYNOPSIS
    Automated Deployment Script for AECIP on AWS.
    Initializes Terraform, provisions ECR, builds & pushes Docker containers, and applies full cloud infrastructure.
#>

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       AECIP: Automated Cloud Deployment on AWS             " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Check prerequisites
Write-Host "`n[Step 1/5] Checking prerequisites..." -ForegroundColor Yellow

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: 'terraform' CLI is not found in PATH." -ForegroundColor Red
    Write-Host "Please install Terraform from: https://developer.hashicorp.com/terraform/install" -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: 'aws' CLI is not found in PATH." -ForegroundColor Red
    Write-Host "Please install AWS CLI from: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: 'docker' CLI is not found in PATH. Make sure Docker Desktop is running." -ForegroundColor Red
    exit 1
}

# Verify AWS credentials
Write-Host "Verifying AWS credentials..." -ForegroundColor Gray
$caller = aws sts get-caller-identity 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: AWS credentials are not configured or invalid." -ForegroundColor Red
    Write-Host "Please run 'aws configure' first." -ForegroundColor Yellow
    exit 1
}
Write-Host "AWS authenticated successfully!" -ForegroundColor Green

# 2. Initialize Terraform
Write-Host "`n[Step 2/5] Initializing Terraform..." -ForegroundColor Yellow
Push-Location terraform
terraform init
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Host "Terraform init failed." -ForegroundColor Red
    exit 1
}

# 3. Create ECR repositories first so Docker can push images
Write-Host "`n[Step 3/5] Provisioning Amazon ECR Repositories..." -ForegroundColor Yellow
terraform apply -target=aws_ecr_repository.api -target=aws_ecr_repository.dashboard -auto-approve
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Write-Host "Failed to provision ECR repositories." -ForegroundColor Red
    exit 1
}

$api_repo = (terraform output -raw ecr_api_repository_url).Trim()
$dash_repo = (terraform output -raw ecr_dashboard_repository_url).Trim()
$region = (terraform output -raw aws_region 2>$null)
if (-not $region) { $region = "us-east-1" }
$registry = $api_repo.Split('/')[0]

Pop-Location

# 4. Build and push Docker images
Write-Host "`n[Step 4/5] Logging into Amazon ECR and pushing container images..." -ForegroundColor Yellow
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $registry

Write-Host "Building and pushing Flask API image: $api_repo:latest" -ForegroundColor Cyan
docker build -t "$api_repo`:latest" -f Dockerfile.api .
docker push "$api_repo`:latest"

Write-Host "Building and pushing Streamlit Dashboard image: $dash_repo:latest" -ForegroundColor Cyan
docker build -t "$dash_repo`:latest" -f Dockerfile.dashboard .
docker push "$dash_repo`:latest"

# 5. Apply full Terraform infrastructure
Write-Host "`n[Step 5/5] Deploying full infrastructure on AWS (VPC, RDS, ECS Fargate, ALB)..." -ForegroundColor Yellow
Push-Location terraform
terraform apply -auto-approve

if ($LASTEXITCODE -eq 0) {
    $alb_url = (terraform output -raw dashboard_url).Trim()
    $api_health = (terraform output -raw api_health_endpoint).Trim()
    Write-Host "`n============================================================" -ForegroundColor Green
    Write-Host "       AECIP DEPLOYMENT SUCCESSFUL!                         " -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "Live Streamlit Dashboard: $alb_url" -ForegroundColor Yellow
    Write-Host "Live Flask API Health:    $api_health" -ForegroundColor Yellow
    Write-Host "`nTo view monitoring: Open AWS Console -> CloudWatch -> Dashboards -> 'aecip-prod-monitoring'" -ForegroundColor Cyan
    Write-Host "To tear down and stop billing: Run .\destroy_aws.ps1" -ForegroundColor Gray
} else {
    Write-Host "`nTerraform deployment encountered an error." -ForegroundColor Red
}

Pop-Location
