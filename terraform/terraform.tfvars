# Production Terraform configuration for AECIP
aws_region               = "ap-southeast-2"
environment              = "prod"
project_name             = "aecip"
db_name                  = "enterprise_segmentation_v2"
db_username              = "postgres"
db_password              = "AecipSecurePass2026!"
db_instance_class        = "db.t4g.micro"
db_allocated_storage     = 20
api_task_cpu             = 512
api_task_memory          = 1024
dashboard_task_cpu       = 512
dashboard_task_memory    = 1024
api_desired_count        = 1
dashboard_desired_count  = 1
retraining_cron_schedule = "cron(0 2 ? * SUN *)"
