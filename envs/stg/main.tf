terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      Environment = var.env
      Project     = var.project_name
    })
  }
}

data "aws_caller_identity" "current" {}

module "terraform_runner_policy" {
  source = "../../modules/terraform-runner-policy"

  env                        = var.env
  project_name               = var.project_name
  aws_region                 = var.aws_region
  account_id                 = data.aws_caller_identity.current.account_id
  allow_assume_principal_arns = var.terraform_runner_allow_assume_principal_arns
  tags                       = var.tags
}

module "vpc" {
  source = "../../modules/vpc"

  env          = var.env
  vpc_cidr     = var.vpc_cidr
  az_count     = var.az_count
  project_name = var.project_name
  tags         = var.tags
}
