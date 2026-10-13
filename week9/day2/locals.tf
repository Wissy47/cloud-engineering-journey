locals {
  name_prefix = "${var.project_name}-${var.environment}"

  bucket_name = "${local.name_prefix}-w9d2-${var.bucket_suffix}"
}
