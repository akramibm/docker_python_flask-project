stage('Generate Terraform Config') {
            echo 'Generating Terraform configuration without IAM read queries...'
            sh """
                mkdir -p ${tfDir}
                cat << 'EOF' > ${tfDir}/main.tf
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
  region = "us-east-1"
}

# 1. Security Group
resource "aws_security_group" "flask_ec2_sg" {
  name        = "flask-docker-ec2-sg"
  description = "Security group allowing SSH, HTTP and port 5000"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Nginx HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Direct Flask App"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. EC2 Instance with AMI and IAM profile directly assigned
resource "aws_instance" "flask_app_ec2" {
  ami                  = "ami-02b64aa047cb5edf5"
  instance_type        = "t2.micro"
  vpc_security_group_ids = [aws_security_group.flask_ec2_sg.id]
  iam_instance_profile = "terraform_ec2"

  user_data = <<-USERDATA
              #!/bin/bash
              set -e
              apt-get update -y
              apt-get install -y docker.io nginx git curl

              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu

              cat << 'NGINX_CONF' > /etc/nginx/sites-available/default
              server {
                  listen 80;
                  server_name _;
                  location / {
                      proxy_pass http://127.0.0.1:5000;
                      proxy_set_header Host \\\$host;
                      proxy_set_header X-Real-IP \\\$remote_addr;
                      proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
                  }
              }
              NGINX_CONF

              systemctl restart nginx
              systemctl enable nginx

              cd /home/ubuntu
              git clone https://github.com/akramibm/docker_python_flask-project.git
              cd docker_python_flask-project
              docker build -t flask-app:latest .
              docker run -d --name flask-app-service -p 5000:5000 --restart unless-stopped flask-app:latest
              USERDATA

  tags = {
    Name = "flask-app-production-ec2"
  }
}

output "public_ip" {
  value = aws_instance.flask_app_ec2.public_ip
}

output "app_url" {
  value = "http://\${aws_instance.flask_app_ec2.public_ip}:5000"
}

output "nginx_url" {
  value = "http://\${aws_instance.flask_app_ec2.public_ip}"
}
EOF
            """
        }
