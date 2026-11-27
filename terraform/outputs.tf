output "ec2_public_ip" {
  description = "Public IP address of the AECIP cloud server."
  value       = aws_instance.aecip_server.public_ip
}

output "dashboard_url" {
  description = "Direct URL to access the Streamlit Executive Dashboard."
  value       = "http://${aws_instance.aecip_server.public_ip}:8501"
}

output "api_health_endpoint" {
  description = "Direct URL to probe the Flask API health."
  value       = "http://${aws_instance.aecip_server.public_ip}:5000/health"
}

output "s3_artifacts_bucket" {
  description = "Name of the S3 bucket hosting datasets and ML model artifacts."
  value       = aws_s3_bucket.artifacts.id
}
