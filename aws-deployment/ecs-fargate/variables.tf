variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "growthbook"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number
  default     = 2
}

variable "docker_image" {
  description = "Docker image for GrowthBook"
  type        = string
  default     = "growthbook/growthbook:latest"
}

variable "task_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 2048
}

variable "task_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 4096
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 10
}

variable "cpu_target_value" {
  description = "Target CPU utilization for auto-scaling"
  type        = number
  default     = 70.0
}

variable "memory_target_value" {
  description = "Target memory utilization for auto-scaling"
  type        = number
  default     = 80.0
}

variable "mongodb_uri" {
  description = "MongoDB connection URI (e.g., mongodb://user:pass@host:27017/db)"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT secret (leave empty to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "encryption_key" {
  description = "Encryption key (leave empty to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "app_origin" {
  description = "Frontend origin URL (e.g., https://growthbook.example.com)"
  type        = string
}

variable "api_host" {
  description = "Backend API URL (e.g., https://api.growthbook.example.com)"
  type        = string
}

variable "frontend_domain" {
  description = "Frontend domain name"
  type        = string
  default     = ""
}

variable "backend_domain" {
  description = "Backend domain name"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS (leave empty to use HTTP only)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

variable "additional_environment_variables" {
  description = "Additional environment variables for the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

