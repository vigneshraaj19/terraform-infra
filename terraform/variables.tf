variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix used for all resources"
  type        = string
  default     = "worktracker"
}

variable "environment" {
  description = "Environment name (e.g. prod, staging)"
  type        = string
  default     = "prod"
}

variable "container_port" {
  description = "Port the React app's container listens on (nginx default)"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = .25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# --- GitHub OIDC settings ---
variable "github_org" {
  description = "GitHub username or organization"
  type        = string
  default     = "vigneshraaj19"
}

variable "github_repo" {
  description = "GitHub repository containing this Terraform infrastructure"
  type        = string
  default     = "terraform-infra"
}

variable "app_github_repo" {
  description = "Your React app repo's name - used for the app-deploy role's trust policy"
  type        = string
    default     = "worktracker"
}

variable "github_branch" {
  description = "Branch allowed to assume the deploy role"
  type        = string
  default     = "main"
}
