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

module "vpc" {
  source = "../../modules/vpc"

  env          = var.env
  vpc_cidr     = var.vpc_cidr
  az_count     = var.az_count
  project_name = var.project_name
  tags         = var.tags
}
