terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.94.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Uncomment and configure to use remote state (recommended for team use)
  # backend "s3" {
  #   bucket         = "cka-tf-state"
  #   key            = "cka-studies/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "cka-tf-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = local.common_tags
  }
}
