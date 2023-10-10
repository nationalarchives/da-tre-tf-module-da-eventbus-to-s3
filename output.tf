output "sns_firehose_eventbus_capture_s3_arn" {
  value       = aws_kinesis_firehose_delivery_stream.sns_firehose_eventbus_capture_s3.arn
  description = "ARN of the firehose stream to delivers to S3"
}

output "sns_firehose_delivery_role_arn" {
  value       = aws_iam_role.sns_firehose_delivery_role.arn
  description = "ARN of the role allowing SNS to publish to firehose"
}
