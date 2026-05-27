provider "aws" {
  region  = var.region
  profile = (var.profile != null && var.profile != "") ? var.profile : null
  ignore_tags {
    key_prefixes = ["deployed_at"]
  }
}

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.32.0"
    }
  }
}
