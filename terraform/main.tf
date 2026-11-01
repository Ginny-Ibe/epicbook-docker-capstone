# ---------------------------------------------------------
# Availability Zones
# ---------------------------------------------------------

# Pin the subnet to the first AZ so t3.micro is always available
# (not every us-east-1 AZ supports it).
data "aws_availability_zones" "available" {
  state = "available"
}

# ---------------------------------------------------------
# VPC
# ---------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "epicbook-vpc"
  }
}

# ---------------------------------------------------------
# Public Subnet
# ---------------------------------------------------------

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "epicbook-public-subnet"
  }
}

# ---------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "epicbook-igw"
  }
}

# ---------------------------------------------------------
# Route Table
# ---------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "epicbook-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------
# Security Group
# ---------------------------------------------------------

# Only two inbound ports: SSH from the admin IP, HTTP from anywhere.
# Frontend (80), backend (8080) and MySQL (3306) are never exposed -
# they are reachable only on the Docker networks inside the VM.
resource "aws_security_group" "main" {
  name        = "epicbook-sg"
  description = "SSH from admin IP only, HTTP from anywhere"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # HTTP
  ingress {
    description = "HTTP to reverse proxy"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "epicbook-sg"
  }
}

# ---------------------------------------------------------
# AWS SSH Key Pair
# ---------------------------------------------------------

resource "aws_key_pair" "main" {
  key_name   = "epicbook-capstone-key"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = {
    Name = "epicbook-capstone-key"
  }
}

# ---------------------------------------------------------
# Ubuntu 22.04 LTS AMI
# ---------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ---------------------------------------------------------
# EC2 Instance
# ---------------------------------------------------------

resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.main.id]

  key_name = aws_key_pair.main.key_name

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  # Require IMDSv2 tokens for the instance metadata service
  metadata_options {
    http_tokens = "required"
  }

  # Install Docker + Compose plugin and add swap on first boot
  user_data = file("${path.module}/cloud-init.yaml")

  # A newer Ubuntu AMI or an edited cloud-init must not replace the running VM
  lifecycle {
    ignore_changes = [ami, user_data]
  }

  tags = {
    Name = "epicbook-capstone"
  }
}
