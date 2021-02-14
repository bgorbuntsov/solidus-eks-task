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

resource "random_string" "random" {
  length  = 16
  special = false
}

provider "aws" {
  region = data.terraform_remote_state.eks.outputs.region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_security_group" "default" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = data.terraform_remote_state.eks.outputs.rds_database

  engine            = "mysql"
  engine_version    = "5.7.31"
  instance_class    = "db.t3.micro"
  allocated_storage = 5
  storage_encrypted = false

  publicly_accessible = true

  name     = data.terraform_remote_state.eks.outputs.rds_database
  username = data.terraform_remote_state.eks.outputs.rds_user
  password = random_string.random.result
  port     = "3306"

  vpc_security_group_ids = [data.aws_security_group.default.id]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  multi_az = false

  # disable backups to create DB faster
  backup_retention_period = 0

  tags = {
    environment = "dev"
    created_by  = "terraform"
    owner       = data.terraform_remote_state.eks.outputs.corpname
  }

  enabled_cloudwatch_logs_exports = ["audit", "general"]

  # DB subnet group
  subnet_ids = data.aws_subnet_ids.all.ids

  # DB parameter group
  family = "mysql5.7"

  # DB option group
  major_engine_version = "5.7"

  # Snapshot name upon DB deletion
  final_snapshot_identifier = data.terraform_remote_state.eks.outputs.rds_database

  # Database Deletion Protection
  deletion_protection = false

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8"
    },
    {
      name  = "character_set_server"
      value = "utf8"
    }
  ]

  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"

      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT"
        },
        {
          name  = "SERVER_AUDIT_FILE_ROTATIONS"
          value = "37"
        },
      ]
    },
  ]
}

resource "null_resource" "save_dump" {
  provisioner "local-exec" {
    command = "wget -O dump.sql https://raw.githubusercontent.com/bgorbuntsov/solidus/main/customers.sql"
  }
  depends_on = [ module.db ]
}

resource "null_resource" "load_dump" {
  provisioner "local-exec" {
    command = "mysql -h ${module.db.this_db_instance_address} -P 3306 -u ${module.db.this_db_instance_username} -p'${random_string.random.result}' -D ${module.db.this_db_instance_name} < dump.sql"
  }
  depends_on = [ null_resource.save_dump ]
}

