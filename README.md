<!-- BEGIN_TF_DOCS -->


# terraform-aws-s3-bucket-logging

GitHub: [fapd777/terraform-module-s3-bucket-logging](https://github.com/fapd777/terraform-module-s3-bucket-logging)

This Terraform module creates a centralized s3 bucket for logging in the account that can later be configured for centralized logging.

### This module configures a bucket with:
- Server Side Encryption (Not KMS)
- Requires encrypted transit

### Example - Simple

```hcl
module "s3_bucket_logging" {
  source             = "git::https://github.com/fapd777/terraform-module-s3-bucket-logging.git"
  name_prefix        = var.name_prefix
  input_tags         = local.common_tags
  versioning_enabled = true #Enabled by default
}
```

### Example - Remote Logging

```hcl
module "s3_bucket_logging" {
  source             = "git::https://github.com/fapd777/terraform-module-s3-bucket-logging.git"
  name_prefix        = var.name_prefix
  input_tags         = local.common_tags
  versioning_enabled = true #Enabled by default
}
```

### Example - Regional

```hcl
module "s3_bucket_logging_us_east_2" {
  source             = "git::https://github.com/fapd777/terraform-module-s3-bucket-logging.git"
  name_prefix = var.name_prefix
  input_tags  = merge(local.common_tags, {})
  providers = {
    aws = aws.us-east-2
  }
  versioning_enabled = true #Enabled by default
}
```

### Example - Regional
Below is an example of the required source IAM policy to coordinate making this work

```hcl
data "aws_iam_policy_document" "s3_replication" {
  statement {
    sid = "AllowS3SourceReplication"
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging"
    ]
    resources = [
      "arn:aws:s3:::${module.s3_bucket_logging_us_east_1.bucket_id}/*"
    ]
  }
  statement {
    sid = "AllowS3SourceReplicationMetadata"
    actions = [
      "s3:ListBucket",
      "s3:GetReplicationConfiguration"
    ]
    resources = [
      "arn:aws:s3:::${module.s3_bucket_logging_us_east_1.bucket_id}"
    ]
  }

  //Destination bucket objects
  statement {
    sid = "AllowS3SourceReplicationObjects"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:ObjectOwnerOverrideToBucketOwner"
    ]
    resources = [
      "arn:aws:s3:::${var.s3_destination_bucket_name}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_role_assumption" {
  name        = "S3-replication-policy"
  description = "Policy to allow S3 role assumption for centralized logging"
  policy      = data.aws_iam_policy_document.s3_replication.json
}


module "iam_role_s3" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 4"

  trusted_role_services = ["s3.amazonaws.com"]

  create_role       = true
  role_requires_mfa = false #No MFA since it's a service

  role_name = "${var.name_prefix}-s3-central-replication" #The assuming account matches it based upon name

  custom_role_policy_arns = [
    aws_iam_policy.s3_role_assumption.arn
  ]

  tags = {
    "Name" = "${var.name_prefix}-s3-central-replication"
  }
}
```

---

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.bucket_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_replication_configuration.replication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_replication_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_s3_bucket_server_side_encryption_type"></a> [aws\_s3\_bucket\_server\_side\_encryption\_type](#input\_aws\_s3\_bucket\_server\_side\_encryption\_type) | Selection of the bucket encryption type | `string` | `"SSE_S3"` | no |
| <a name="input_days_to_object_expiration"></a> [days\_to\_object\_expiration](#input\_days\_to\_object\_expiration) | Number of days before expiring data completely | `string` | `"2557"` | no |
| <a name="input_enable_centralized_logging"></a> [enable\_centralized\_logging](#input\_enable\_centralized\_logging) | Enable support for centralized logging to a centralized logging account | `bool` | `false` | no |
| <a name="input_enable_object_expiration"></a> [enable\_object\_expiration](#input\_enable\_object\_expiration) | Number of days before expiring data completely | `bool` | `false` | no |
| <a name="input_iam_role_s3_replication_arn"></a> [iam\_role\_s3\_replication\_arn](#input\_iam\_role\_s3\_replication\_arn) | IAM Role that enable S3 Role Assumption for Centralized Logging | `string` | `""` | no |
| <a name="input_input_tags"></a> [input\_tags](#input\_input\_tags) | Map of tags to apply to resources | `map(string)` | `{}` | no |
| <a name="input_logging_account_id"></a> [logging\_account\_id](#input\_logging\_account\_id) | Logging Account Number | `string` | `""` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | String to prefix on object names | `string` | n/a | yes |
| <a name="input_replication_dest_storage_class"></a> [replication\_dest\_storage\_class](#input\_replication\_dest\_storage\_class) | The storage class to send replicated objects (https://docs.aws.amazon.com/AmazonS3/latest/API/API_Transition.html#AmazonS3-Type-Transition-StorageClass) | `string` | `"STANDARD_IA"` | no |
| <a name="input_s3_destination_bucket_name"></a> [s3\_destination\_bucket\_name](#input\_s3\_destination\_bucket\_name) | Centralized Logging Bucket Name | `string` | `""` | no |
| <a name="input_transition_expiration"></a> [transition\_expiration](#input\_transition\_expiration) | Number of days before expiring data completely | `string` | `"2557"` | no |
| <a name="input_transition_glacier"></a> [transition\_glacier](#input\_transition\_glacier) | Number of days before transitioning data to Glacier | `string` | `"366"` | no |
| <a name="input_transition_ia"></a> [transition\_ia](#input\_transition\_ia) | Number of days before transitioning data to S3 Infrequently Accessed | `string` | `"180"` | no |
| <a name="input_versioning_enabled"></a> [versioning\_enabled](#input\_versioning\_enabled) | Enable versioning on the S3 bucket, this is mainly for S3 logging replication | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | outputs the full arn of the bucket created |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | outputs the id of the bucket created |

---

## Notes
Note, manual changes to the README will be overwritten when the documentation is updated. To update the documentation, run `terraform-docs -c .config/.terraform-docs.yml .`
<!-- END_TF_DOCS -->