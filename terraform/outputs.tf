output "api_url" {
  description = "API Gateway HTTP API invoke URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID (ai-o11y-frontend)"
  value       = aws_cognito_user_pool_client.frontend.id
}

output "cognito_region" {
  description = "AWS region where Cognito is deployed"
  value       = var.aws_region
}

output "cognito_domain" {
  description = "Full Cognito hosted UI domain"
  value       = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}
