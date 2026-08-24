# Terraform and provider configuration.
#
# This block lives in the environment and never in a module: a module that
# declares its own provider cannot be reused with a different region or a
# different account.
#
# No credentials are set here either. The AWS provider uses the standard
# credential chain: environment variables, a shared profile in
# ~/.aws/credentials, or an instance role.

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

  # Applied to every resource that supports tagging, in this environment and in
  # every module it calls, so individual resources only declare their own Name.
  default_tags {
    tags = var.common_tags
  }
}
