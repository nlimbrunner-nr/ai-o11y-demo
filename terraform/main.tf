terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # NOTE: This backend must be bootstrapped first by running the config in ./bootstrap/
  # before initializing this root module.
  backend "s3" {
    bucket         = "ai-o11y-terraform-state"
    key            = "ai-o11y/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "ai-o11y-terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format, used for OIDC trust (e.g. myorg/ai-o11y-demo)"
  type        = string
}

variable "app_name" {
  description = "Short application name used as a prefix for resource names"
  type        = string
  default     = "ai-o11y"
}

variable "agentcore_memory_id" {
  description = "AgentCore Memory ID for persistent conversation history. Leave empty to run without memory."
  type        = string
  default     = ""
}
