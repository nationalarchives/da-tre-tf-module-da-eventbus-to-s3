# Create the bucket for archiving
resource "aws_s3_bucket" "s3_bucket_tre_out_archive" {
  bucket = "${var.env}-${var.prefix}-tre-out-archive"
}

resource "aws_s3_bucket_acl" "s3_tre_out_archive_acl" {
  bucket = aws_s3_bucket.s3_bucket_tre_out_archive.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "s3_bucket_tre_out_archive_block_public" {
  bucket                  = aws_s3_bucket.s3_bucket_tre_out_archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create IAM service account for Kinesis
resource "aws_iam_role" "firehose_archive_role" {
  name                 = "${var.env}-${var.prefix}-firehose-archive-role"
  assume_role_policy   = data.aws_iam_policy_document.firehose_archive_role_assume_policy.json
  permissions_boundary = var.tre_permission_boundary_arn
}


data "aws_iam_policy_document" "firehose_archive_role_assume_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "firehose_archive_role_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucketMultipartUploads",
      "s3:AbortMultipartUpload",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      "${aws_s3_bucket.s3_bucket_tre_out_archive.arn}/*",
      "${aws_s3_bucket.s3_bucket_tre_out_archive.arn}"
    ]
  }
}

resource "aws_iam_policy" "firehose_archive_role_policy" {
  name        = "${var.env}-${var.prefix}-firehose-archive-role-policy"
  description = "Policy for firehouse to dump to S3 for archiving"
  policy      = data.aws_iam_policy_document.firehose_archive_role_policy.json
}

resource "aws_iam_role_policy_attachment" "firehose_archive_role_policy_attach" {
  role       = aws_iam_role.firehose_archive_role.name
  policy_arn = aws_iam_policy.firehose_archive_role_policy.arn
}

# Create IAM role for SNS -> Firehose
resource "aws_iam_role" "sns_firehose_delivery_role" {
  name                 = "${var.env}-${var.prefix}-sns-firehose-delivery-role"
  assume_role_policy   = data.aws_iam_policy_document.sns_firehose_delivery_role_assume_policy.json
  permissions_boundary = var.tre_permission_boundary_arn
}

data "aws_iam_policy_document" "sns_firehose_delivery_role_assume_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "sns_firehose_delivery_role_policy" {
  statement {
    effect = "Allow"

    actions = [
      "firehose:DescribeDeliveryStream",
      "firehose:ListDeliveryStreams",
      "firehose:ListTagsForDeliveryStream",
      "firehose:PutRecord",
      "firehose:PutRecordBatch"
    ]

    resources = [
      "${aws_kinesis_firehose_delivery_stream.sns_firehose_tre_out_archive_s3.arn}"
    ]
  }
}

resource "aws_iam_policy" "sns_firehose_delivery_role_policy" {
  name        = "${var.env}-${var.prefix}-sns-firehose-delivery-role-policy"
  description = "policy for SNS to send to firehose"
  policy      = data.aws_iam_policy_document.sns_firehose_delivery_role_policy.json
}

resource "aws_iam_role_policy_attachment" "sns_firehose_delivery_role_policy_attach" {
  role       = aws_iam_role.sns_firehose_delivery_role.name
  policy_arn = aws_iam_policy.sns_firehose_delivery_role_policy.arn
}

# Firehose
resource "aws_kinesis_firehose_delivery_stream" "sns_firehose_tre_out_archive_s3" {
  name        = "${var.env}-${var.prefix}-sns-firehose-tre-out-archive-s3"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn        = aws_iam_role.firehose_archive_role.arn
    bucket_arn      = aws_s3_bucket.s3_bucket_tre_out_archive.arn
    buffer_interval = 60
    buffer_size     = 64

    dynamic_partitioning_configuration {
      enabled = "true"
    }
    prefix              = "judgmentpackage.available.JudgmentPackageAvailable/!{partitionKeyFromQuery:orginator}/!{partitionKeyFromQuery:reference}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/"

    processing_configuration {
      enabled = true

      processors {
        type = "MetadataExtraction"
        parameters {
          parameter_name  = "MetadataExtractionQuery"
          parameter_value = "{orginator:.parameters.originator,reference:.parameters.reference}"
        }
        parameters {
          parameter_name  = "JsonParsingEngine"
          parameter_value = "JQ-1.6"
        }
      }
    }
  }
}

resource "aws_sns_topic_subscription" "sns_firehose_tre_out_archive_s3_subscription" {
  topic_arn             = var.tre_out_topic_arn
  protocol              = "firehose"
  subscription_role_arn = aws_iam_role.sns_firehose_delivery_role.arn
  endpoint              = aws_kinesis_firehose_delivery_stream.sns_firehose_tre_out_archive_s3.arn
  raw_message_delivery  = true
  filter_policy = jsonencode(
    {
      "properties" : {
        "messageType" : [
          "uk.gov.nationalarchives.tre.messages.judgmentpackage.available.JudgmentPackageAvailable"
        ]
      }
  })
  filter_policy_scope = "MessageBody"
}
