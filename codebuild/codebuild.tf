terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.27.0"
    }
  }
}

provider "aws" {
  region = data.terraform_remote_state.eks.outputs.region
}

data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../eks/cluster/terraform.tfstate"
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_policy" "ECRFullAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_codebuild_source_credential" "example" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = data.terraform_remote_state.eks.outputs.github_token
}

resource "aws_iam_role" "codebuild-role" {
  for_each       = toset(data.terraform_remote_state.eks.outputs.apps_list)
  name               = "codebuild-role-${each.key}"
  assume_role_policy = file("./codebuild-role.json")
}

resource "aws_iam_policy" "codebuild-policy" {
  for_each       = toset(data.terraform_remote_state.eks.outputs.apps_list)
  name   = "CodeBuildPolicy-${data.terraform_remote_state.eks.outputs.corpname}-${each.key}"
  policy = templatefile("./codebuild-policy.json", { region = data.aws_region.current.name, account_id = data.aws_caller_identity.current.account_id, name = each.key })
}

resource "aws_iam_role_policy_attachment" "codebuild-role-policy-attach" {
  for_each       = toset(data.terraform_remote_state.eks.outputs.apps_list)
  role       = aws_iam_role.codebuild-role[each.key].name
  policy_arn = aws_iam_policy.codebuild-policy[each.key].arn
}

resource "aws_iam_role_policy_attachment" "codebuild-role-aws-policy-attach" {
  for_each       = toset(data.terraform_remote_state.eks.outputs.apps_list)
  role       = aws_iam_role.codebuild-role[each.key].name
  policy_arn = data.aws_iam_policy.ECRFullAccess.arn
}

resource "aws_codebuild_project" "build-app" {
  for_each       = toset(data.terraform_remote_state.eks.outputs.apps_list)
  name           = "${each.key}-build-project"
  description    = "${each.key}-codebuild_project"
  build_timeout  = "60"
  queued_timeout = "60"
  service_role   = aws_iam_role.codebuild-role[each.key].arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "NO_CACHE"
  }

  badge_enabled = "false"

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = "true"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      type  = "PLAINTEXT"
      value = data.aws_region.current.name
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      type  = "PLAINTEXT"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "IMAGE_TAG"
      type  = "PLAINTEXT"
      value = "latest"
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      type  = "PLAINTEXT"
      value = "${each.key}-app"
    }
  }
  logs_config {
    cloudwatch_logs {
      group_name = "build-log/${each.key}"
      status     = "ENABLED"
    }

    s3_logs {
      status = "DISABLED"
    }
  }

  source {
    type                = "GITHUB"
    report_build_status = "false"
    location            = "${data.terraform_remote_state.eks.outputs.reponame_prefix}${data.terraform_remote_state.eks.outputs.corpname}-${each.key}.git"
    git_clone_depth     = 1
    git_submodules_config {
      fetch_submodules = "false"
    }
    insecure_ssl = "false"
  }

  tags = {
    environment = "dev"
    author      = "boris"
  }
}

resource "aws_codebuild_webhook" "github_hook" {
  for_each     = toset(data.terraform_remote_state.eks.outputs.apps_list)
  project_name = aws_codebuild_project.build-app[each.key].name
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
  }
  depends_on = [ aws_codebuild_project.build-app ]
}
