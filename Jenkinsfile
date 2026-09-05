properties([
    parameters([
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy'],
            description: 'Choose whether to provision or tear down the EC2 infrastructure'
        )
    ])
])

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
  name_prefix = "flask-docker-ec2-sg-"
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
  ami                    = "ami-02b64aa047cb5edf5"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.flask_ec2_sg.id]

  user_data = <<-USERDATA
              #!/bin/bash
              export DEBIAN_FRONTEND=noninteractive

              # Update and install Docker and Nginx
              apt-get update -y
              apt-get install -y -o Dpkg::Options::="--force-confold" docker.io nginx git curl

              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu

              # Configure Nginx reverse proxy
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

              # Clone repo and launch container
              cd /home/ubuntu
              git clone https://github.com/akramibm/docker_python_flask-project.git app-repo
              cd app-repo

              docker build -t flask-app:latest .
              docker run -d --name flask-app-service -p 5000:5000 --restart unless-stopped flask-app:latest
              USERDATA

  tags = {
    Name = "flask-app-production-ec2"
  }
}

output "public_ip" {
  value       = aws_instance.flask_app_ec2.public_ip
  description = "Public IP"
}

output "app_url" {
  value       = "http://${aws_instance.flask_app_ec2.public_ip}:5000"
  description = "Direct Flask URL"
}

output "nginx_url" {
  value       = "http://${aws_instance.flask_app_ec2.public_ip}"
  description = "Nginx Proxy URL"
}
'''
        }

        stage('Terraform Action') {
            dir(tfDir) {
                sh 'terraform init -input=false'

                if (params.ACTION == 'destroy') {
                    echo "Destroying EC2 and Security Group infrastructure..."
                    sh 'terraform destroy -auto-approve -input=false'
                } else {
                    echo "Applying infrastructure..."
                    sh 'terraform apply -auto-approve -input=false'
                    sh 'terraform output -raw app_url > ../app_url.txt'
                    sh 'terraform output -raw nginx_url > ../nginx_url.txt'
                }
            }
        }

        stage('Summary') {
            if (params.ACTION == 'apply') {
                def appUrl   = readFile('app_url.txt').trim()
                def nginxUrl = readFile('nginx_url.txt').trim()
                echo "=========================================================="
                echo "Deployment Complete!"
                echo "Flask Direct URL : ${appUrl}"
                echo "Nginx Proxy URL  : ${nginxUrl}"
                echo "Note: Wait ~2 minutes for Docker image build to complete."
                echo "=========================================================="
            } else {
                echo "=========================================================="
                echo "Infrastructure Destroyed Successfully."
                echo "=========================================================="
            }
        }

    } catch (err) {
        echo "Pipeline failed: ${err.getMessage()}"
        throw err
    }
}
