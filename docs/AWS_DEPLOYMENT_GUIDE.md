# AECIP on the Cloud: Containerised AWS Deployment Guide

This guide documents the enterprise cloud architecture, containerisation strategy, Infrastructure as Code (Terraform), CI/CD pipelines (GitHub Actions), and scheduled autonomous retraining workflows for the **Adaptive Enterprise Customer Intelligence Platform (AECIP)** on **Amazon Web Services (AWS)**.

---

## 🏛️ High-Level Cloud Architecture

```mermaid
flowchart TD
    subgraph Users ["External Traffic & Clients"]
        Client["Web Users & CRM API Clients"]
        Dev["Developers / CI/CD Push"]
    end

    subgraph GitHub ["GitHub Infrastructure"]
        GHA["GitHub Actions CI/CD\n(Lint, Test, Docker Build, ECR Push)"]
    end

    subgraph AWS ["Amazon Web Services (AWS Cloud)"]
        subgraph Edge ["Edge & Networking Layer"]
            ALB["Application Load Balancer (ALB)\n(Port 80/443 Routing)"]
            NAT["NAT Gateway (Outbound Internet for Private Tasks)"]
        end

        subgraph ECS ["Amazon ECS (Fargate Serverless Containers)"]
            API_TASK["AECIP Flask API Service\n(Port 5000, 2 Replicas, Gunicorn)"]
            DASH_TASK["AECIP Streamlit Dashboard Service\n(Port 8501, 1 Replica)"]
            RETRAIN_TASK["One-Off Retraining Fargate Task\n(AutoML & Drift Scoring)"]
        end

        subgraph Storage ["Persistent & State Storage"]
            RDS[("Amazon RDS PostgreSQL\n(Multi-AZ, Encrypted, Private Subnets)")]
            S3[("Amazon S3 Artifacts Bucket\n(Model Weights .pkl, Datasets, Versioned)")]
        end

        subgraph EventAndServerless ["Automated Retraining Engine"]
            EB["Amazon EventBridge Rule\n(Weekly Cron / Event Trigger)"]
            Lambda["AWS Lambda Retrainer\n(Orchestrates ECS RunTask)"]
        end

        subgraph Monitoring ["Observability & Auditing"]
            CW_LOGS["CloudWatch Logs (/ecs/aecip-*)"]
            CW_METRICS["CloudWatch Metrics & Alarms\n(CPU, Memory, Drift, RDS Storage)"]
            CW_DASH["CloudWatch Unified Dashboard"]
        end

        subgraph Registries ["Container Registry"]
            ECR_API["Amazon ECR: aecip-api"]
            ECR_DASH["Amazon ECR: aecip-dashboard"]
        end
    end

    Client -->|HTTP / HTTPS| ALB
    ALB -->|/api/*, /predict*, /health| API_TASK
    ALB -->|/* (Default UI)| DASH_TASK

    Dev -->|git push main| GHA
    GHA -->|Push Docker Images| ECR_API
    GHA -->|Push Docker Images| ECR_DASH
    GHA -->|Trigger Rolling Deployment| ECS

    API_TASK -->|Query/Upsert Features| RDS
    API_TASK -->|Pull/Sync Model Weights| S3
    DASH_TASK -->|Query Reports & Analytics| RDS
    DASH_TASK -->|Load Precomputed Models| S3

    EB -->|Scheduled Trigger| Lambda
    Lambda -->|Dispatches RunTask| RETRAIN_TASK
    RETRAIN_TASK -->|Evaluate Drift & Retrain| RDS
    RETRAIN_TASK -->|Persist New .pkl Artifacts| S3

    ECS -.->|Stdout / Stderr| CW_LOGS
    ECS -.->|Container Insights| CW_METRICS
    RDS -.->|Performance Metrics| CW_METRICS
    CW_METRICS --> CW_DASH
```

---

## 📦 1. Containerisation with Docker

AECIP provides two isolated, security-hardened container images:

1. **Flask API Container (`Dockerfile.api`)**:
   - Built on `python:3.11-slim`.
   - Runs under an unprivileged `appuser` (UID 1000).
   - Powered by **Gunicorn WSGI** (`--workers 2 --threads 4 --timeout 120`).
   - Integrated healthcheck: `curl -f http://localhost:5000/health || exit 1`.
   - Exposes port `5000`.

2. **Streamlit Dashboard Container (`Dockerfile.dashboard`)**:
   - Built on `python:3.11-slim`.
   - Runs in headless production mode (`--server.headless=true`).
   - Native Streamlit healthcheck: `curl -f http://localhost:8501/_stcore/health || exit 1`.
   - Exposes port `8501`.

### Local Testing with Docker Compose

To test the entire multi-container architecture locally with PostgreSQL:

```bash
# 1. Start the complete stack (Postgres + API + Dashboard)
docker-compose up --build -d

# 2. View logs
docker-compose logs -f

# 3. Access endpoints
# - Streamlit Dashboard: http://localhost:8501
# - Flask API: http://localhost:5000/health
# - Prediction endpoint: POST http://localhost:5000/predict-churn

# 4. Stop containers
docker-compose down -v
```

---

## ☁️ 2. AWS Cloud Components & Data Layer

### Amazon RDS PostgreSQL
- Private database subnets across multiple Availability Zones.
- Accessible strictly from ECS Fargate tasks and the Retraining Lambda security group.
- Automated storage scaling (up to 100 GB) with `gp3` storage and encryption at rest.

### Amazon S3 Model & Dataset Storage
- Bucket: `aecip-cloud-artifacts-<env>-<suffix>`
- **Object Versioning enabled**: Preserves historical machine learning weights (`models/churn_model.pkl`, `models/clv_model.pkl`, `models/best_automl_model.pkl`) to allow immediate model rollbacks.
- **SSE-S3 Encryption**: AES-256 server-side encryption.
- **Lifecycle Policies**: Automatically archives older model iterations to `STANDARD_IA` after 60 days.

---

## 🛠️ 3. Infrastructure as Code (IaC) with Terraform

All AWS infrastructure is managed under the `terraform/` directory.

### Directory Structure

```
terraform/
├── providers.tf            # AWS & provider configurations (v5.0+)
├── variables.tf            # Input variables (CIDRs, DB specs, Task sizes)
├── terraform.tfvars.example # Sample configuration values
├── vpc.tf                  # VPC, 6 Subnets (Public/Private/DB), NAT GW, Security Groups
├── s3.tf                   # S3 Bucket with versioning, encryption, and lifecycle rules
├── rds.tf                  # Amazon RDS PostgreSQL instance and parameter groups
├── ecr.tf                  # Amazon ECR container repositories with lifecycle cleanup
├── alb.tf                  # Application Load Balancer with path-based routing rules
├── ecs.tf                  # ECS Cluster, Task Definitions, and Fargate Services
├── iam.tf                  # Execution, Task, and Lambda IAM roles (Least Privilege)
├── cloudwatch.tf           # Alarms (CPU, Memory, RDS storage) and Unified Dashboard
├── lambda_eventbridge.tf   # EventBridge cron trigger and Lambda Retrainer
└── outputs.tf              # ALB DNS, RDS endpoint, S3 bucket name
```

### Deploying the Infrastructure

```bash
cd terraform

# 1. Initialize Terraform and download providers
terraform init

# 2. Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your chosen database password and region

# 3. Review planned resources
terraform plan

# 4. Provision infrastructure
terraform apply -auto-approve

# 5. Extract outputs
terraform output alb_dns_name
terraform output s3_artifacts_bucket
```

---

## 🔄 4. CI/CD Pipelines with GitHub Actions

The automated pipeline is defined in `.github/workflows/ci_cd.yml`.

### Pipeline Stages

1. **Quality & Unit Tests (`test-and-lint`)**:
   - Executes Python code linting with `flake8`.
   - Runs unit tests for S3 fallback, drift metrics calculation, action rules, and API endpoints.

2. **Terraform Validation (`terraform-check`)**:
   - Enforces formatting (`terraform fmt -check`).
   - Validates configuration integrity (`terraform validate`).

3. **Build & Deploy (`build-and-deploy`)**:
   - Triggers on push to `main`.
   - Logs into Amazon ECR.
   - Builds, tags, and pushes `aecip-api` and `aecip-dashboard` images.
   - Updates Amazon ECS services with rolling zero-downtime deployment.
   - Verifies ECS service stability.

### Required GitHub Secrets

Configure the following secrets under your GitHub repository (**Settings > Secrets and variables > Actions**):

| Secret Name | Description |
| :--- | :--- |
| `AWS_ACCESS_KEY_ID` | AWS IAM user access key with deployment permissions |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM user secret access key |

---

## 🤖 5. Scheduled Automated Model Retraining

AECIP features autonomous, closed-loop model maintenance powered by **Amazon EventBridge** and **AWS Lambda**:

```
[ Amazon EventBridge ] (Weekly Schedule / cron(0 2 ? * SUN *))
         │
         ▼
[ AWS Lambda Retrainer ] (lambda/retrain_handler.py)
         │
         ▼
[ Amazon ECS Fargate RunTask ] (aecip-retrainer container)
         │
         ├── 1. Fetches recent RFM data from Amazon RDS
         ├── 2. Computes PSI and KL Divergence drift scores
         ├── 3. If Severe Drift detected -> Triggers AutoML Tuner
         ├── 4. Tests RandomForest, GradientBoosting, and XGBoost
         ├── 5. Serializes winning weights -> Uploads to Amazon S3
         └── 6. Emits CloudWatch custom metric 'RetrainingJobsTriggered'
```

---

## 📊 6. System Monitoring with Amazon CloudWatch

AECIP integrates observability across all application layers:

1. **Log Aggregation**:
   - `/ecs/aecip-prod-api`: Application logs from Flask API.
   - `/ecs/aecip-prod-dashboard`: Application logs from Streamlit.
   - `/ecs/aecip-prod-retraining`: Execution logs from automated training jobs.
   - `/aws/lambda/aecip-prod-scheduled-retrainer`: Retrainer Lambda logs.

2. **CloudWatch Alarms**:
   - `aecip-prod-api-high-cpu`: Triggers if API container CPU $\ge 80\%$.
   - `aecip-prod-api-high-memory`: Triggers if API container Memory $\ge 85\%$.
   - `aecip-prod-rds-high-cpu`: Triggers if PostgreSQL CPU $\ge 80\%$.
   - `aecip-prod-rds-low-storage`: Triggers if RDS storage falls below 5 GB.

3. **Unified CloudWatch Dashboard (`aecip-prod-monitoring`)**:
   - Live ECS CPU and Memory utilization widgets.
   - ALB request throughput and target response times.
   - Amazon RDS active database connections and compute load.
