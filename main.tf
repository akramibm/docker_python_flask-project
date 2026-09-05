terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Fetch the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group: Allow SSH, HTTP (Nginx), and direct Flask port
resource "aws_security_group" "flask_app_sg" {
  name        = "flask-app-sg"
  description = "Security group for Flask Docker deployment with Nginx"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP - Nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask direct access"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flask-app-sg"
  }
}

# EC2 Instance
resource "aws_instance" "flask_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.flask_app_sg.id]

  # Automated setup: installs Docker, Nginx, clones repo, and runs container
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 1. Update system and install required packages
              apt-get update -y
              apt-get install -y docker.io nginx git curl

              # 2. Start and enable Docker
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu

              # 3. Configure Nginx as reverse proxy to Flask (port 5000)
              cat << 'NGINX_CONF' > /etc/nginx/sites-available/default
              server {
                  listen 80;
                  server_name _;

                  location / {
                      proxy_pass http://127.0.0.1:5000;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                  }
              }
              NGINX_CONF

              systemctl restart nginx
              systemctl enable nginx

              # 4. Clone repo, build image, and run container in detached mode
              cd /home/ubuntu
              git clone https://github.com/akramibm/docker_python_flask-project.git
              cd docker_python_flask-project

              docker build -t flask-app:latest .
              docker run -d \
                --name flask-app-service \
                -p 5000:5000 \
                --restart unless-stopped \
                flask-app:latest
              EOF

  tags = {
    Name = "flask-docker-ec2"
  }
}
