variable "apps_list" {
  type    = list(string)
  default = ["scale", "numbers", "names", "content"]
}

variable "corpname" {}

variable "domainname" {}

variable "reponame_prefix" {}

variable "github_token" {}

variable "region" {}

variable "rds_database" {}

variable "rds_user" {}

