# Terraform and provider configuration.
#
# No credentials are set here. The AWS provider uses the standard credential
# chain: environment variables, a shared profile in ~/.aws/credentials, or an
# instance/container role.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Applied to every resource that supports tagging, so individual resources
  # only have to declare their own Name tag.
  default_tags {
    tags = var.common_tags
  }
}
