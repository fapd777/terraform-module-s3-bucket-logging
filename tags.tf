locals {
  common_tags = merge(var.input_tags, {
    "ModuleSourceRepo" = "https://github.com/fapd777/terraform-module-s3-bucket-logging"
  })
}