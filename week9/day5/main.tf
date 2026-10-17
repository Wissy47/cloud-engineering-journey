locals {
  bucket_name = "cloudlab-week9-day5-${var.bucket_suffix}"
}

module "storage" {
  source      = "./modules/s3"
  bucket_name = local.bucket_name

  tags = {
    Name      = local.bucket_name
    Lab       = "Week9Day5"
    ManagedBy = "Terraform"
  }
}
module "backups" {
  source      = "./modules/s3"
  bucket_name = "cloudlab-week9-day5-backups-${var.bucket_suffix}"
  tags = {
    Name      = "cloudlab-week9-day5-backups-${var.bucket_suffix}"
    Lab       = "Week9Day5"
    Purpose   = "Backups"
    ManagedBy = "Terraform"
  }
}
