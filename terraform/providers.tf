terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Uncomment to store remote state in S3 with DynamoDB locking
  # backend "s3" {
  #   bucket         = "aecip-terraform-state-bucket"
  #   key            = "aecip/production/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "aecip-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "AECIP"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
