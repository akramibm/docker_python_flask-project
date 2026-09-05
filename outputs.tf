output "public_ip" {
  value = aws_instance.flask_server.public_ip
}

output "nginx_url" {
  description = "Access via Nginx reverse proxy on port 80"
  value       = "http://${aws_instance.flask_server.public_ip}"
}

output "flask_direct_url" {
  description = "Access directly on port 5000"
  value       = "http://${aws_instance.flask_server.public_ip}:5000"
}
