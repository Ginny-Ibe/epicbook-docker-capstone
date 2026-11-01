# ------------------------
# Region
# ------------------------
variable "aws_region" {
  description = "AWS region where the infrastructure will be created"
  type        = string
  default     = "us-east-1"
}

# ------------------------
# Network
# ------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (routed to the Internet Gateway)"
  type        = string
  default     = "10.0.1.0/24"
}

# ---------------------------------
# EC2 Instance
# ---------------------------------
variable "instance_type" {
  description = "EC2 instance type (t3.micro is free-tier eligible; cloud-init adds swap so MySQL fits)"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root disk size in GB (images + MySQL data + backups; free tier allows up to 30)"
  type        = number
  default     = 20
}

# ------------------------
# Access
# ------------------------
variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH to the VM - your public IP as x.x.x.x/32"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the public SSH key on the local machine"
  type        = string
  default     = "~/.ssh/terraform-aws-epicbook-vm-key.pub"
}

# ------------------------
# CI/CD
# ------------------------
variable "github_repo" {
  description = "GitHub repository (owner/name) allowed to assume the CI deploy role"
  type        = string
  default     = "Ginny-Ibe/epicbook-docker-capstone"
}
