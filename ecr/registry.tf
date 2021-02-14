terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.27.0"
    }
  }
}

data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../eks/cluster/terraform.tfstate"
  }
}

provider "aws" {
  region = data.terraform_remote_state.eks.outputs.region
}

resource "aws_ecr_repository" "app" {
  for_each             = toset(data.terraform_remote_state.eks.outputs.apps_list)
  name                 = "${each.key}-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
}
