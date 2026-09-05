properties([
    parameters([
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy'],
            description: 'Select apply to provision or destroy to tear down infrastructure'
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

        stage('Install Tools') {
            echo 'Verifying Terraform and AWS CLI...'
            sh '''
                if ! command -v terraform &> /dev/null; then
                    sudo apt-get update -y && sudo apt-get install -y gnupg software-properties-common curl
                    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
                    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
                    sudo apt-get update -y && sudo apt-get install -y terraform
                fi
            '''
        }

        stage('Generate Terraform Config') {
            echo 'Writing Terraform configuration file...'
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
  ami                         = "ami-02b64aa047cb5edf5"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.flask_ec2_sg.id]
  iam_instance_profile        = "terraform_ec2"
  user_data_replace_on_change = true

  depends_on = [
    aws_security_group.flask_ec2_sg
  ]

  user_data = <<-USERDATA
              #!/bin/bash
              exec > /var/log/user-data.log 2>&1
              set -ex

              export DEBIAN_FRONTEND=noninteractive
              sed -i "s/#\\$nrconf{restart} = 'i';/\\$nrconf{restart} = 'a';/g" /etc/needrestart/needrestart.conf 2>/dev/null || true

              apt-get update -y
              apt-get install -y -o Dpkg::Options::="--force-confold" docker.io nginx git curl

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
              rm -rf app
              git clone https://github.com/akramibm/docker_python_flask-project.git app
              cd app
              docker build -t flask-app:latest .
              docker run -d --name flask-app-service -p 5000:5000 --restart unless-stopped flask-app:latest
              USERDATA

  tags = {
    Name = "flask-app-production-ec2"
  }
}

output "instance_id" {
  value = aws_instance.flask_app_ec2.id
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

        stage('Terraform Action') {
            dir(tfDir) {
                sh 'terraform init -input=false'

                if (params.ACTION == 'destroy') {
                    echo "Destroying infrastructure..."
                    sh 'terraform destroy -auto-approve -input=false'
                } else {
                    echo "Applying infrastructure..."
                    sh 'terraform apply -auto-approve -input=false'
                    sh 'terraform output -raw app_url > ../app_url.txt'
                    sh 'terraform output -raw nginx_url > ../nginx_url.txt'
                    sh 'terraform output -raw instance_id > ../instance_id.txt'
                    sh 'terraform output -raw public_ip > ../public_ip.txt'
                }
            }
        }

        stage('Wait & Verify Application') {
            if (params.ACTION != 'destroy') {
                def targetIp   = readFile('public_ip.txt').trim()
                def instanceId = readFile('instance_id.txt').trim()
                echo "Polling http://${targetIp}:5000 until the container boots up..."

                sh """
                    READY=0
                    for i in {1..30}; do
                        echo "Attempt \$i/30: Checking if app is responding..."
                        if curl -s -f -m 5 "http://${targetIp}:5000" > /dev/null || curl -s -f -m 5 "http://${targetIp}" > /dev/null; then
                            echo "Application is UP and serving traffic!"
                            READY=1
                            break
                        fi
                        sleep 10
                    done

                    if [ \$READY -eq 0 ]; then
                        echo "ERROR: Application failed to start within 5 minutes."
                        echo "Fetching EC2 System Console Log to diagnose failure without SSH:"
                        aws ec2 get-console-output --instance-id "${instanceId}" --region us-east-1 --output text || true
                        exit 1
                    fi
                """
            }
        }

        stage('Deployment Summary') {
            if (params.ACTION != 'destroy') {
                def appUrl   = readFile('app_url.txt').trim()
                def nginxUrl = readFile('nginx_url.txt').trim()
                echo "=========================================================="
                echo "Deployment Verified & Running!"
                echo "Direct Flask URL : ${appUrl}"
                echo "Nginx Proxy URL  : ${nginxUrl}"
                echo "=========================================================="
            } else {
                echo "Infrastructure destroyed."
            }
        }

    } catch (err) {
        echo "Pipeline failed: ${err.getMessage()}"
        throw err

    } finally {
        stage('Cleanup Local Artifacts') {
            sh 'rm -f app_url.txt nginx_url.txt instance_id.txt public_ip.txt'
        }
    }
}
