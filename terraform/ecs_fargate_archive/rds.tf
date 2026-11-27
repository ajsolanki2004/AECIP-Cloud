# --- RDS DB Subnet Group ---
resource "aws_db_subnet_group" "rds" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  description = "Subnet group for AECIP PostgreSQL RDS database"
  subnet_ids  = aws_subnet.database[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# --- RDS Parameter Group ---
resource "aws_db_parameter_group" "pg15" {
  name        = "${var.project_name}-${var.environment}-pg15-params"
  family      = "postgres15"
  description = "Custom parameter group for AECIP PostgreSQL 15 database"

  parameter {
    name  = "rds.force_ssl"
    value = "0" # Allows both SSL and local verification flexibility
  }
}

# --- Amazon RDS PostgreSQL Instance ---
resource "aws_db_instance" "postgres" {
  identifier                  = "${var.project_name}-${var.environment}-db"
  engine                      = "postgres"
  engine_version              = "15"
  instance_class              = var.db_instance_class
  allocated_storage           = var.db_allocated_storage
  max_allocated_storage       = 100 # Enables automatic storage autoscaling
  storage_type                = "gp3"
  storage_encrypted           = true

  db_name                     = var.db_name
  username                    = var.db_username
  password                    = var.db_password

  db_subnet_group_name        = aws_db_subnet_group.rds.name
  parameter_group_name        = aws_db_parameter_group.pg15.name
  vpc_security_group_ids      = [aws_security_group.rds.id]

  publicly_accessible         = false
  multi_az                    = false # Set to true for multi-AZ high availability in mission-critical environments
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false

  backup_retention_period     = 7
  backup_window               = "03:00-04:00"
  maintenance_window          = "Mon:04:30-Mon:05:30"

  skip_final_snapshot         = true
  deletion_protection         = false

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-postgres"
  }
}
