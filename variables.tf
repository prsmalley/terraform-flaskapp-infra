variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "flaskapp"
}

variable "instance_type" {
  description = "EC2 instance type. t3.small minmum for k3s + ARC"
  type        = string
  default     = "t3.small"
}

variable "ssh_public_key_path" {
  description = "Absolute path to the local SSH public key to install on the instance"
  type        = string
}

variable "my_ip" {
  description = "Public IP, no CIDR suffix. SSH and app access restricted to this IP."
  type        = string
}
