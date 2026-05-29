# ---------------------------------------------------------------------------
# Lambda execution role — ai-o11y-chat (Python / Bedrock)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "chat_lambda" {
  name               = "ai-o11y-chat-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "chat_lambda_basic" {
  role       = aws_iam_role.chat_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "bedrock_invoke" {
  statement {
    effect  = "Allow"
    actions = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = [
      "arn:aws:bedrock:*::foundation-model/*",
      "arn:aws:bedrock:*:*:inference-profile/*",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["bedrock-agentcore:*"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "aws-marketplace:ViewSubscriptions",
      "aws-marketplace:Subscribe",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "chat_lambda_bedrock" {
  name   = "bedrock-invoke"
  role   = aws_iam_role.chat_lambda.id
  policy = data.aws_iam_policy_document.bedrock_invoke.json
}

# ---------------------------------------------------------------------------
# Lambda execution role — ai-o11y-graphql (Go)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "graphql_lambda" {
  name               = "ai-o11y-graphql-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "graphql_lambda_basic" {
  role       = aws_iam_role.graphql_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC provider & deployment role
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint list for token.actions.githubusercontent.com (GitHub's current CA)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "ai-o11y-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

data "aws_iam_policy_document" "github_actions_deploy" {
  # Terraform remote state — S3
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::ai-o11y-terraform-state",
      "arn:aws:s3:::ai-o11y-terraform-state/*",
    ]
  }

  # Terraform remote state — DynamoDB lock
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/ai-o11y-terraform-lock",
    ]
  }

  # Lambda layer access — needed to attach New Relic layers (published in NR's AWS account)
  statement {
    effect    = "Allow"
    actions   = ["lambda:GetLayerVersion"]
    resources = ["arn:aws:lambda:${var.aws_region}:451483290750:layer:NewRelic*:*"]
  }

  # Lambda — full lifecycle + permissions management
  statement {
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetPolicy",
      "lambda:ListVersionsByFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:TagResource",
      "lambda:UntagResource",
    ]
    resources = [
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:ai-o11y-chat",
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:ai-o11y-graphql",
    ]
  }

  # IAM — manage roles, inline policies, and managed policy attachments
  statement {
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:CreateRole",
      "iam:UpdateRole",
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ai-o11y-*",
    ]
  }

  # IAM — OIDC provider lifecycle
  statement {
    effect = "Allow"
    actions = [
      "iam:GetOpenIDConnectProvider",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com",
    ]
  }

  # Cognito — user pool, app client, and domain lifecycle
  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPool",
      "cognito-idp:CreateUserPool",
      "cognito-idp:UpdateUserPool",
      "cognito-idp:DeleteUserPool",
      "cognito-idp:DescribeUserPoolClient",
      "cognito-idp:CreateUserPoolClient",
      "cognito-idp:UpdateUserPoolClient",
      "cognito-idp:DeleteUserPoolClient",
      "cognito-idp:DescribeUserPoolDomain",
      "cognito-idp:CreateUserPoolDomain",
      "cognito-idp:DeleteUserPoolDomain",
      "cognito-idp:ListTagsForResource",
      "cognito-idp:TagResource",
      "cognito-idp:UntagResource",
      "cognito-idp:SetUserPoolMfaConfig",
      "cognito-idp:GetUserPoolMfaConfig",
    ]
    resources = ["*"]
  }

  # Firehose backup S3 bucket
  statement {
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketTagging",
      "s3:PutBucketTagging",
      "s3:GetLifecycleConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:GetBucketAcl",
      "s3:GetBucketCORS",
      "s3:GetBucketLogging",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketPolicy",
      "s3:GetBucketPolicyStatus",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:GetEncryptionConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:GetAccelerateConfiguration",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.app_name}-firehose-backup-${data.aws_caller_identity.current.account_id}",
      "arn:aws:s3:::${var.app_name}-firehose-backup-${data.aws_caller_identity.current.account_id}/*",
    ]
  }

  # Kinesis Firehose
  statement {
    effect = "Allow"
    actions = [
      "firehose:CreateDeliveryStream",
      "firehose:DeleteDeliveryStream",
      "firehose:DescribeDeliveryStream",
      "firehose:UpdateDestination",
      "firehose:TagDeliveryStream",
      "firehose:UntagDeliveryStream",
      "firehose:ListTagsForDeliveryStream",
    ]
    resources = [
      "arn:aws:firehose:${var.aws_region}:${data.aws_caller_identity.current.account_id}:deliverystream/${var.app_name}-*",
    ]
  }

  # CloudWatch Metric Streams
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricStream",
      "cloudwatch:GetMetricStream",
      "cloudwatch:DeleteMetricStreams",
      "cloudwatch:StartMetricStreams",
      "cloudwatch:StopMetricStreams",
      "cloudwatch:ListMetricStreams",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
      "cloudwatch:ListTagsForResource",
    ]
    resources = ["*"]
  }

  # API Gateway v2 — full lifecycle
  statement {
    effect = "Allow"
    actions = [
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:PATCH",
      "apigateway:DELETE",
      "apigateway:TagResource",
    ]
    resources = ["arn:aws:apigateway:${var.aws_region}::*"]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}
