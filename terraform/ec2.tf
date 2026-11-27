# --- EC2 Instance Running Docker & Docker Compose ---
resource "aws_instance" "aecip_server" {
  ami                         = var.ubuntu_ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 1. Update OS packages and install Docker dependencies
              apt-get update -y
              apt-get install -y ca-certificates curl gnupg git

              # 2. Install official Docker Engine & Docker Compose
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              chmod a+r /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

              systemctl enable docker
              systemctl start docker

              # 3. Pull AECIP platform and spin up containers
              mkdir -p /opt/aecip
              cd /opt/aecip
              git clone ${var.repo_url} .
              cat <<ENVEOF > .env
              AWS_REGION=${var.aws_region}
              AECIP_S3_BUCKET=${aws_s3_bucket.artifacts.id}
              ENVEOF
              docker compose up -d --build
              EOF

  tags = {
    Name        = "${var.project_name}-${var.environment}-server"
    Description = "AECIP Cloud Server running Dockerized PostgreSQL, Flask API, and Streamlit Dashboard"
  }
}
