module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = local.cluster_name
  cluster_version = "1.18"
  subnets         = module.vpc.private_subnets

  tags = {
    Environment = "dev"
    GithubRepo  = "terraform-aws-eks"
  }

  vpc_id = module.vpc.vpc_id

  workers_group_defaults = {
    root_volume_type = "gp2"
  }

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t3.micro"
      asg_desired_capacity          = 2
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    },
    {
      name                          = "worker-group-2"
      instance_type                 = "t3.small"
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_two.id]
      asg_desired_capacity          = 2
    },
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

resource "aws_iam_policy" "allow_ecr_access" {
  name        = "allow_ecr"
  description = "permissions for Amazon ECR"
  path        = "/"
  policy      = file("./policy_for_worker_nodes.json")
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  role       = module.eks.worker_iam_role_name
  policy_arn = aws_iam_policy.allow_ecr_access.arn
}

output "role_arn" {
  value = module.eks.worker_iam_role_arn
}
output "role_name" {
  value = module.eks.worker_iam_role_name
}

resource "null_resource" "kubectl_config" {
  provisioner "local-exec" {
    command = "/bin/bash kubectlconfig.sh"
  }
  depends_on = [ module.eks ]
}

resource "null_resource" "k8s_healthcheck" {
  provisioner "local-exec" {
    command = "kubectl get services --all-namespaces"
  }
  depends_on = [ null_resource.kubectl_config ]
}



