module "network" {
  source = "./modules/network"

  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = var.availability_zone

  environment  = var.environment
  project_name = var.project_name

  tags = local.common_tags
}
module "storage" {
  source = "./modules/storage"

  bucket_name = local.artifact_bucket_name
  tags        = local.common_tags
}