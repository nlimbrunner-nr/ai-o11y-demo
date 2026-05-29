# ---------------------------------------------------------------------------
# Dummy zip archives — replaced by CI/CD on real deploys
# ---------------------------------------------------------------------------

data "archive_file" "chat_placeholder" {
  type        = "zip"
  output_path = "${path.module}/.placeholder/chat_placeholder.zip"

  source {
    content  = "# placeholder — replaced by CI/CD deploy"
    filename = "handler.py"
  }
}

data "archive_file" "graphql_placeholder" {
  type        = "zip"
  output_path = "${path.module}/.placeholder/graphql_placeholder.zip"

  source {
    content  = "# placeholder — replaced by CI/CD deploy"
    filename = "bootstrap"
  }
}

# ---------------------------------------------------------------------------
# ai-o11y-chat  (Python 3.12, calls Bedrock)
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "chat" {
  function_name = "ai-o11y-chat"
  role          = aws_iam_role.chat_lambda.arn

  runtime          = "python3.12"
  handler          = "newrelic_lambda_wrapper.handler"
  filename         = data.archive_file.chat_placeholder.output_path
  source_code_hash = data.archive_file.chat_placeholder.output_base64sha256

  architectures = ["arm64"]
  timeout       = 60
  memory_size   = 512

  layers = [
    local.nr_python312_arm64_layer,
    local.nr_extension_arm64_layer,
  ]

  environment {
    variables = {
      COGNITO_USER_POOL_ID  = aws_cognito_user_pool.main.id
      COGNITO_CLIENT_ID     = aws_cognito_user_pool_client.frontend.id
      COGNITO_REGION        = var.aws_region
      GRAPHQL_API_URL       = "${aws_apigatewayv2_api.main.api_endpoint}/graphql"
      BEDROCK_REGION        = "us-east-1"
      BEDROCK_MODEL_ID      = "us.anthropic.claude-sonnet-4-6"
      AGENTCORE_MEMORY_ID   = var.agentcore_memory_id

      NEW_RELIC_APP_NAME                            = "ai-o11y-chat"
      NEW_RELIC_ACCOUNT_ID                          = tostring(var.new_relic_account_id)
      NEW_RELIC_LICENSE_KEY                         = var.new_relic_license_key
      NEW_RELIC_LAMBDA_HANDLER                      = "handler.handler"
      NEW_RELIC_EXTENSION_SEND_FUNCTION_LOGS        = "true"
      NEW_RELIC_DISTRIBUTED_TRACING_ENABLED         = "true"
      NEW_RELIC_AI_MONITORING_ENABLED               = "true"
      NEW_RELIC_AI_MONITORING_RECORD_CONTENT_ENABLED = "true"
    }
  }

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

resource "aws_lambda_permission" "apigw_chat" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# ---------------------------------------------------------------------------
# ai-o11y-graphql  (Go on provided.al2023)
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "graphql" {
  function_name = "ai-o11y-graphql"
  role          = aws_iam_role.graphql_lambda.arn

  runtime          = "provided.al2023"
  handler          = "bootstrap"
  filename         = data.archive_file.graphql_placeholder.output_path
  source_code_hash = data.archive_file.graphql_placeholder.output_base64sha256

  architectures = ["arm64"]
  timeout       = 30
  memory_size   = 128

  layers = [
    local.nr_extension_arm64_layer,
  ]

  environment {
    variables = {
      NEW_RELIC_APP_NAME                     = "ai-o11y-graphql"
      NEW_RELIC_ACCOUNT_ID                   = tostring(var.new_relic_account_id)
      NEW_RELIC_LICENSE_KEY                  = var.new_relic_license_key
      NEW_RELIC_EXTENSION_SEND_FUNCTION_LOGS = "true"
    }
  }

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

resource "aws_lambda_permission" "apigw_graphql" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.graphql.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
