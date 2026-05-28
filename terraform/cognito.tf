resource "aws_cognito_user_pool" "main" {
  name = "ai-o11y-users"

  # Email is the username; phone is not used
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Admins create users; no self-signup
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  tags = {
    Project   = "ai-o11y"
    ManagedBy = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cognito_user_pool_client" "frontend" {
  name         = "ai-o11y-frontend"
  user_pool_id = aws_cognito_user_pool.main.id

  # No client secret (public SPA client)
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.app_name}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}
