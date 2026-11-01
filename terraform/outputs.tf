# ---------------------------------
# EC2 Instance
# ---------------------------------
output "public_ip" {
  description = "Public IP address of the EpicBook VM"
  value       = aws_instance.main.public_ip
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.main.id
}

# ------------------------
# Access
# ------------------------
output "ssh_command" {
  description = "Command to SSH into the VM"
  value       = "ssh -i ~/.ssh/terraform-aws-epicbook-vm-key ubuntu@${aws_instance.main.public_ip}"
}

output "app_url" {
  description = "EpicBook through the reverse proxy"
  value       = "http://${aws_instance.main.public_ip}"
}

output "health_url" {
  description = "Public health endpoint through the reverse proxy"
  value       = "http://${aws_instance.main.public_ip}/health"
}

# ------------------------
# Security Group
# ------------------------
output "security_group_id" {
  description = "ID of the security group (SSH from admin IP, HTTP from anywhere)"
  value       = aws_security_group.main.id
}

# ------------------------
# CI/CD
# ------------------------
output "ci_role_arn" {
  description = "IAM role GitHub Actions assumes via OIDC (secret AWS_ROLE_ARN)"
  value       = aws_iam_role.ci_deploy.arn
}
