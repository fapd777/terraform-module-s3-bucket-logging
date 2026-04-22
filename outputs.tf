output "bucket_arn" {
  description = "outputs the full arn of the bucket created"
  value       = aws_s3_bucket.bucket.arn
}

output "bucket_id" {
  description = "outputs the id of the bucket created"
  value       = aws_s3_bucket.bucket.id
}