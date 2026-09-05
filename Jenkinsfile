node {
    def tfDir      = 'terraform'
    def gitCredsId = 'token123'
    def repoUrl    = 'https://github.com/akramibm/docker_python_flask-project.git'

    try {
        stage('Checkout Code') {
            echo "Checking out repository..."
            git branch: 'main',
                credentialsId: gitCredsId,
                url: repoUrl
        }

        stage('Install Terraform') {
            echo 'Ensuring Terraform CLI is present...'
            sh '''
                if ! command -v terraform &> /dev/null; then
                    echo "Installing Terraform CLI..."
                    sudo apt-get update -y && sudo apt-get install -y gnupg software-properties-common curl
                    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
                    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
                    sudo apt-get update -y && sudo apt-get install -y terraform
                else
                    echo "Terraform already installed: $(terraform -version | head -n 1)"
                fi
            '''
        }

        stage('Generate Terraform Config') {
            echo 'Writing Terraform configuration file via writeFile...'
            sh "mkdir -p ${tfDir}"
            
            writeFile file: "${tfDir}/main.tf", text: '''terraform {
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

resource "aws_security_group" "flask_ec2_sg" {
  name        = "flask-docker-ec2-sg"
  description = "Allow SSH, HTTP and port 5000"

  lifecycle {
    create_before_destroy = true
  }

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
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
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
  value = "http://${aws_instance.flask_app_ec2.public_ip}:5000"
}

output "nginx_url" {
  value = "http://${aws_instance.flask_app_ec2.public_ip}"
}
'''
        }

        stage('Terraform Init & Apply') {
            echo 'Initializing and provisioning AWS EC2 with terraform_ec2 IAM profile...'
            dir(tfDir) {
                sh 'terraform init -input=false'
                sh 'terraform apply -auto-approve -input=false'
                sh 'terraform output -raw app_url > ../app_url.txt'
                sh 'terraform output -raw nginx_url > ../nginx_url.txt'
            }
        }

        stage('Deployment Summary') {
            def appUrl   = readFile('app_url.txt').trim()
            def nginxUrl = readFile('nginx_url.txt').trim()
            echo "=========================================================="
            echo "Deployment Completed Successfully!"
            echo "AMI Used         : ami-02b64aa047cb5edf5"
            echo "IAM Role Attached: terraform_ec2"
            echo "Direct Flask URL : ${appUrl}"
            echo "Nginx Proxy URL  : ${nginxUrl}"
            echo "=========================================================="
        }

    } catch (err) {
        echo "Pipeline run failed: ${err.getMessage()}"
        throw err

    } finally {
        stage('Cleanup Local Artifacts') {
            sh 'rm -f app_url.txt nginx_url.txt'
        }
    }
}
