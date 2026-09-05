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

data "aws_vpc" "default" {
  default = true
}

# Security group opening SSH, HTTP (80 for Nginx), and 5000 (Flask directly)
resource "aws_security_group" "web_sg" {
  name        = "flask-nginx-sg"
  description = "Allow HTTP, Flask port, and SSH inbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP Nginx Reverse Proxy"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Direct Flask App Port"
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

  tags = {
    Name = "flask-nginx-sg"
  }
}

resource "aws_instance" "flask_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Cloud-init provisioning: installs Docker & Nginx reverse proxy
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io nginx curl git

              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu

              # Configure Nginx reverse proxy to forward port 80 to port 5000
              cat << 'CONF' > /etc/nginx/sites-available/default
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
              CONF

              systemctl restart nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "flask-docker-nginx-host"
  }
}
