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
  # Update Lambda function code
  statement {
    effect = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
    ]
    resources = [
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:ai-o11y-chat",
      "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:ai-o11y-graphql",
    ]
  }

  # Read/write Terraform remote state
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

  # DynamoDB state lock
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
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}
