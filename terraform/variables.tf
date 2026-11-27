variable "aws_region" {
  description = "Target AWS Region for deployment."
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, prod)."
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project identifier prefix used in resource naming."
  type        = string
  default     = "aecip"
}

variable "vpc_cidr" {
  description = "CIDR block for the AECIP VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to distribute resources across."
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]
}

variable "ubuntu_ami_id" {
  description = "Static Ubuntu 22.04 LTS AMI ID for ap-southeast-2 (bypasses ec2:DescribeImages SCP)."
  type        = string
  default     = "ami-0663918c81e287db1"
}

variable "repo_url" {
  description = "GitHub repository URL cloned onto the EC2 instance."
  type        = string
  default     = "https://github.com/ajsolanki2004/AECIP-Cloud.git"
}

variable "instance_type" {
  description = "EC2 instance compute size (Free Tier eligible: t2.micro or t3.micro)."
  type        = string
  default     = "t3.micro"
}

# --- Database Variables ---
variable "db_name" {
  description = "Name of the default PostgreSQL database."
  type        = string
  default     = "enterprise_segmentation_v2"
}

variable "db_username" {
  description = "Master username for Amazon RDS PostgreSQL."
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Master password for Amazon RDS PostgreSQL."
  type        = string
  sensitive   = true
  default     = "AecipSecurePass2026!"
}

variable "db_instance_class" {
  description = "RDS instance compute class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage (GB) for RDS PostgreSQL."
  type        = number
  default     = 20
}

# --- ECS Container Sizing ---
variable "api_task_cpu" {
  description = "CPU units for the API ECS Fargate task (256 = 0.25 vCPU, 512 = 0.5 vCPU)."
  type        = number
  default     = 512
}

variable "api_task_memory" {
  description = "Memory (MB) for the API ECS Fargate task."
  type        = number
  default     = 1024
}

variable "dashboard_task_cpu" {
  description = "CPU units for the Dashboard ECS Fargate task."
  type        = number
  default     = 512
}

variable "dashboard_task_memory" {
  description = "Memory (MB) for the Dashboard ECS Fargate task."
  type        = number
  default     = 1024
}

variable "api_desired_count" {
  description = "Desired number of running API containers."
  type        = number
  default     = 2
}

variable "dashboard_desired_count" {
  description = "Desired number of running Dashboard containers."
  type        = number
  default     = 1
}

# --- Retraining Schedule ---
variable "retraining_cron_schedule" {
  description = "Amazon EventBridge cron schedule expression for automated retraining."
  type        = string
  default     = "cron(0 2 ? * SUN *)" # Every Sunday at 02:00 AM UTC
}
