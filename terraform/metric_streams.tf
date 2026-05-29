# ---------------------------------------------------------------------------
# CloudWatch Metric Streams → Kinesis Firehose → New Relic
# ---------------------------------------------------------------------------

locals {
  nr_metric_stream_endpoint = var.new_relic_region == "EU" ? "https://aws-api.eu01.nr-data.net/cloudwatch-metrics/v1" : "https://aws-api.newrelic.com/cloudwatch-metrics/v1"
}

# ---------------------------------------------------------------------------
# S3 backup bucket (Firehose requires a backup destination)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "firehose_backup" {
  bucket        = "${var.app_name}-firehose-backup-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id

  rule {
    id     = "expire-backups"
    status = "Enabled"
    filter {}
    expiration {
      days = 7
    }
  }
}

# ---------------------------------------------------------------------------
# IAM role for Kinesis Firehose → S3 + NR HTTP endpoint
# ---------------------------------------------------------------------------

resource "aws_iam_role" "firehose_newrelic" {
  name = "${var.app_name}-firehose-newrelic"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "firehose_s3_backup" {
  name = "s3-backup"
  role = aws_iam_role.firehose_newrelic.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject",
      ]
      Resource = [
        aws_s3_bucket.firehose_backup.arn,
        "${aws_s3_bucket.firehose_backup.arn}/*",
      ]
    }]
  })
}

# ---------------------------------------------------------------------------
# Kinesis Firehose delivery stream
# ---------------------------------------------------------------------------

resource "aws_kinesis_firehose_delivery_stream" "newrelic" {
  name        = "${var.app_name}-metrics-to-newrelic"
  destination = "http_endpoint"

  http_endpoint_configuration {
    url                = local.nr_metric_stream_endpoint
    name               = "New Relic"
    access_key         = var.new_relic_license_key
    buffering_size     = 1
    buffering_interval = 60
    role_arn           = aws_iam_role.firehose_newrelic.arn
    s3_backup_mode     = "FailedDataOnly"

    request_configuration {
      content_encoding = "GZIP"
    }

    s3_configuration {
      role_arn           = aws_iam_role.firehose_newrelic.arn
      bucket_arn         = aws_s3_bucket.firehose_backup.arn
      buffering_size     = 10
      buffering_interval = 400
      compression_format = "GZIP"
    }
  }

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# IAM role for CloudWatch Metric Stream → Firehose
# ---------------------------------------------------------------------------

resource "aws_iam_role" "metric_stream" {
  name = "${var.app_name}-metric-stream"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "streams.metrics.cloudwatch.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "metric_stream_firehose" {
  name = "firehose-put"
  role = aws_iam_role.metric_stream.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
      Resource = [aws_kinesis_firehose_delivery_stream.newrelic.arn]
    }]
  })
}

# ---------------------------------------------------------------------------
# CloudWatch Metric Stream (Lambda + API Gateway namespaces)
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_stream" "newrelic" {
  name          = "${var.app_name}-metrics"
  role_arn      = aws_iam_role.metric_stream.arn
  firehose_arn  = aws_kinesis_firehose_delivery_stream.newrelic.arn
  output_format = "opentelemetry0.7"

  include_filter {
    namespace    = "AWS/Lambda"
    metric_names = []
  }

  include_filter {
    namespace    = "AWS/ApiGateway"
    metric_names = []
  }

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# IAM role for New Relic → AWS account link (entity synthesis)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "newrelic_integration" {
  name = "${var.app_name}-newrelic-integration"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::754728514883:root" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = tostring(var.new_relic_account_id)
        }
      }
    }]
  })

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "newrelic_integration_readonly" {
  role       = aws_iam_role.newrelic_integration.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ---------------------------------------------------------------------------
# New Relic cloud account link
# ---------------------------------------------------------------------------

resource "newrelic_cloud_aws_link_account" "main" {
  account_id = var.new_relic_account_id
  arn        = aws_iam_role.newrelic_integration.arn
  name       = "${var.app_name} AWS"
}
