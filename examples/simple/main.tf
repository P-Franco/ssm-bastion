module "network" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.0"

  name            = "demo"
  cidr            = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
}

module "bastion" {
  source             = "../../" # path up to root of module
  name_prefix        = "demo"
  vpc_id             = module.network.vpc_id
  public_subnet_id   = module.network.public_subnets[0]
  private_subnet_ids = module.network.private_subnets

  ami_id = "ami-04aa00acb1165b32a" # Amazon Linux 2023

  tags = {
    project = "demo"
    owner   = "peter"
  }
}