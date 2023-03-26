data "aws_availability_zones" "available" {}

locals {
  name   = "eksHandson"
  region = "ap-northeast-1"

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  cluster_version = "1.24"

  tags = {
    terraform_project = local.name
  }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = local.name
  cidr = "192.168.0.0/16"

  azs                 = ["${local.region}a", "${local.region}c", "${local.region}d"]
  public_subnets      = ["192.168.0.0/24", "192.168.1.0/24", "192.168.2.0/24"]
  private_subnets     = ["192.168.10.0/24", "192.168.11.0/24", "192.168.12.0/24"]

  private_subnet_names = ["PrivateSubnetA", "PrivateSubnetC", "PrivateSubnetD"]

  # derault NACL, Route table, Security Group
  manage_default_network_acl = true
  default_network_acl_tags   = { Name = "${local.name}-default" }

  manage_default_route_table = true
  default_route_table_tags   = { Name = "${local.name}-default" }

  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  # DNS support
  enable_dns_hostnames = true
  enable_dns_support   = true

  # single NAT Gateway deployment
  enable_nat_gateway = true
  single_nat_gateway = true

  # Tags for AWS Load Balancer Controller
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags  
}

################################################################################
# VPC Endpoints Module
################################################################################

module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [data.aws_security_group.default.id]

  endpoints = {
    s3 = {
      service = "s3"
      tags    = { Name = "s3-vpc-endpoint" }
    },
  }

  tags = merge(local.tags, {
    Endpoint = "true"
  })
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.10.3"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  cluster_addons = {
    kube-proxy = {}
    vpc-cni    = {}
    coredns = {
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group = false
  create_node_security_group    = false

  fargate_profile_defaults = {
    iam_role_additional_policies = {
      additional = aws_iam_policy.additional.arn
    }
  }

  fargate_profiles = merge(
    {
      eksHandson = {
        name = "eksHandson"
        selectors = [
          {
            namespace = "default"
          }
        ]

        timeouts = {
          create = "20m"
          delete = "20m"
        }
      }
    },
    {
      your-alb-sample-app = {
        name = "your-alb-sample-app"
        selectors = [
          {
            namespace = "game-2048"
          }
        ]
      }
    },
    { for i in range(3) :
      "kube-system-${element(split("-", local.azs[i]), 2)}" => {
        selectors = [
          { namespace = "kube-system" }
        ]
        # We want to create a profile per AZ for high availability
        subnet_ids = [element(module.vpc.private_subnets, i)]
      }
    }
  )

  tags = local.tags
}

################################################################################
# IRSA Roles
################################################################################

module "load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.14.4"

  role_name                              = "load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

resource "kubernetes_service_account" "aws_loadbalancer_controller" {
  metadata {
    name = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.load_balancer_controller_irsa_role.iam_role_arn
    }
  }
}

################################################################################
# Supporting Resources
################################################################################

# VPC Endpoint
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

# EKS
resource "aws_iam_policy" "additional" {
  name = "${local.name}-additional"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# Kubernetes setup for terraform
data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks.token
}
