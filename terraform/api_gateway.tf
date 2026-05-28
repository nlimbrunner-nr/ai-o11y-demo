# ---------------------------------------------------------------------------
# HTTP API (API Gateway v2)
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "main" {
  name          = "ai-o11y-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_headers = ["Authorization", "Content-Type"]
    allow_methods = ["POST", "OPTIONS"]
    max_age       = 300
  }

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# JWT authorizer — Cognito
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.frontend.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
  }
}

# ---------------------------------------------------------------------------
# Lambda integrations
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_integration" "chat" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.chat.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "graphql" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.graphql.invoke_arn
  payload_format_version = "2.0"
}

# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_route" "chat" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /chat"
  target             = "integrations/${aws_apigatewayv2_integration.chat.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_route" "graphql" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /graphql"
  target             = "integrations/${aws_apigatewayv2_integration.graphql.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

# ---------------------------------------------------------------------------
# Auto-deploy stage
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }
}
