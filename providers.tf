### Providers ###
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.67.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.2.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile_name

  default_tags {
    tags = {
      app_name = "${var.project_name}-app"
      owner    = var.project_owner
      env      = "vas-dev"
    }
  }
}

provider "azurerm" {
  subscription_id = var.azure_subscription_id

  features {}
}