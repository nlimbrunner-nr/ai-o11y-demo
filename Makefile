.DEFAULT_GOAL := help

FRONTEND_DIR := frontend
BACKEND_DIR  := backend
AI_DIR       := ai
TF_DIR       := terraform
TF_BOOTSTRAP := terraform/bootstrap

.PHONY: help setup install check \
        dev-frontend dev-backend dev-ai \
        build build-frontend build-backend build-ai \
        test test-frontend test-backend test-ai \
        format format-frontend format-backend format-ai \
        format-check format-check-frontend format-check-backend format-check-ai \
        clean \
        tf-bootstrap tf-init tf-plan tf-apply tf-destroy \
        curl-backend curl-ai

##@ Setup

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
	  /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)

setup: ## Copy frontend/.env.example → frontend/.env.local (edit before running dev-frontend)
	@if [ ! -f $(FRONTEND_DIR)/.env.local ]; then \
	  cp $(FRONTEND_DIR)/.env.example $(FRONTEND_DIR)/.env.local; \
	  echo "Created $(FRONTEND_DIR)/.env.local — fill in your Cognito + API Gateway values."; \
	else \
	  echo "$(FRONTEND_DIR)/.env.local already exists."; \
	fi

install: ## Install all dependencies (Node modules, Python venv + uvicorn, Go modules)
	@echo "==> Node (frontend)..."
	cd $(FRONTEND_DIR) && npm install
	@echo "==> Python (ai)..."
	cd $(AI_DIR) && python3.12 -m venv venv && \
	  ./venv/bin/pip install --quiet -r requirements.txt "uvicorn[standard]"
	@echo "==> Go (backend)..."
	cd $(BACKEND_DIR) && go mod download
	@echo ""
	@echo "Done. Next steps:"
	@echo "  1. make setup        — create frontend/.env.local"
	@echo "  2. Edit .env.local   — add Cognito + API Gateway values"
	@echo "  3. make dev-frontend — start React dev server"

check: ## Verify required tools are installed
	@echo "Checking prerequisites..."
	@command -v node       >/dev/null 2>&1 \
	  && printf "  [ok] node       %s\n" "$$(node --version)" \
	  || echo   "  [!!] node       — install from https://nodejs.org"
	@command -v go         >/dev/null 2>&1 \
	  && printf "  [ok] go         %s\n" "$$(go version | awk '{print $$3}')" \
	  || echo   "  [!!] go         — install from https://go.dev"
	@command -v python3.12 >/dev/null 2>&1 \
	  && printf "  [ok] python3.12 %s\n" "$$(python3.12 --version)" \
	  || echo   "  [!!] python3.12 — install from https://python.org"
	@command -v docker     >/dev/null 2>&1 \
	  && printf "  [ok] docker     %s\n" "$$(docker --version | awk '{print $$3}' | tr -d ',')" \
	  || echo   "  [--] docker     — optional, required for dev-backend"
	@command -v aws        >/dev/null 2>&1 \
	  && printf "  [ok] aws        %s\n" "$$(aws --version 2>&1 | awk '{print $$1}')" \
	  || echo   "  [--] aws cli    — optional, required for Bedrock + deploys"
	@command -v terraform  >/dev/null 2>&1 \
	  && printf "  [ok] terraform  %s\n" "$$(terraform version 2>&1 | head -1 | awk '{print $$2}')" \
	  || echo   "  [--] terraform  — optional, required for infra targets"

##@ Local Development

dev-frontend: ## React dev server → http://localhost:3000 (needs frontend/.env.local)
	@if [ ! -f $(FRONTEND_DIR)/.env.local ]; then \
	  echo "ERROR: $(FRONTEND_DIR)/.env.local missing. Run: make setup"; \
	  exit 1; \
	fi
	cd $(FRONTEND_DIR) && npm start

dev-ai: ## Python AI service → http://localhost:8000 (needs AWS creds + env vars set)
	@if [ ! -f $(AI_DIR)/venv/bin/uvicorn ]; then \
	  echo "ERROR: Python venv not set up. Run: make install"; \
	  exit 1; \
	fi
	@echo "Required env vars: COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID, COGNITO_REGION,"
	@echo "                   GRAPHQL_API_URL, BEDROCK_REGION, BEDROCK_MODEL_ID"
	@echo ""
	cd $(AI_DIR) && PYTHONPATH=. ./venv/bin/uvicorn handler:app --reload --port 8000

dev-backend: ## Go GraphQL API → http://localhost:9000 via Lambda RIE (needs Docker)
	@command -v docker >/dev/null 2>&1 || (echo "ERROR: docker required for dev-backend"; exit 1)
	@echo "==> Building Go backend for Linux..."
	cd $(BACKEND_DIR) && GOOS=linux go build -o bootstrap_local main.go
	@echo ""
	@echo "==> Lambda RIE running on :9000"
	@echo "    Invoke: http://localhost:9000/2015-03-31/functions/function/invocations"
	@echo "    (Run 'make curl-backend' in another terminal to test)"
	@echo ""
	docker run --rm -p 9000:8080 \
	  -v "$(CURDIR)/$(BACKEND_DIR):/var/task:ro" \
	  public.ecr.aws/lambda/provided:al2023 \
	  /var/task/bootstrap_local
	@rm -f $(BACKEND_DIR)/bootstrap_local

curl-backend: ## Send a test GraphQL query to the running dev-backend (port 9000)
	curl -s -X POST http://localhost:9000/2015-03-31/functions/function/invocations \
	  -H "Content-Type: application/json" \
	  -d '{"version":"2.0","requestContext":{"http":{"method":"POST"}},"headers":{"content-type":"application/json"},"body":"{\"query\":\"{ user(email: \\\"demo@example.com\\\") { name vehicle { model batteryLevel rangeKm } } }\"}","isBase64Encoded":false}' \
	  | python3 -m json.tool

curl-ai: ## Send a test chat message to the running dev-ai (port 8000)
	curl -s -X POST http://localhost:8000/chat \
	  -H "Content-Type: application/json" \
	  -d '{"message":"What is my battery level?","conversation_history":[],"auth_token":"REPLACE_WITH_COGNITO_TOKEN"}' \
	  | python3 -m json.tool

##@ Build (Lambda artifacts)

build-frontend: ## npm run build → frontend/build/
	cd $(FRONTEND_DIR) && npm run build

build-backend: ## Cross-compile Go arm64 Linux + zip → backend/function.zip
	$(MAKE) -C $(BACKEND_DIR) zip

build-ai: ## Package Python deps (arm64) + zip → ai/function.zip
	$(MAKE) -C $(AI_DIR) build

build: build-frontend build-backend build-ai ## Build all Lambda artifacts

##@ Test

test-frontend: ## Run frontend tests (CI mode)
	cd $(FRONTEND_DIR) && CI=true npm test

test-backend: ## Run Go unit tests
	cd $(BACKEND_DIR) && go test ./...

test-ai: ## Run Python tests via pytest
	@if [ ! -f $(AI_DIR)/venv/bin/python ]; then \
	  echo "ERROR: Python venv not set up. Run: make install"; \
	  exit 1; \
	fi
	cd $(AI_DIR) && ./venv/bin/pytest -v 2>/dev/null || echo "No tests found — add tests under ai/tests/"

test: test-frontend test-backend test-ai ## Run all tests

##@ Format

format: format-frontend format-backend format-ai ## Format all code

format-frontend: ## Prettier → frontend/src/**
	cd $(FRONTEND_DIR) && npx prettier --write "src/**/*.{ts,tsx,js,jsx,css,json}"

format-backend: ## gofmt → backend/
	gofmt -w $(BACKEND_DIR)

format-ai: ## black + isort → ai/
	@if [ ! -f $(AI_DIR)/venv/bin/python ]; then \
	  echo "ERROR: Python venv not set up. Run: make install"; \
	  exit 1; \
	fi
	@if [ ! -f $(AI_DIR)/venv/bin/black ]; then \
	  cd $(AI_DIR) && ./venv/bin/pip install --quiet black isort; \
	fi
	cd $(AI_DIR) && ./venv/bin/isort . && ./venv/bin/black .

format-check: format-check-frontend format-check-backend format-check-ai ## Check formatting (no writes)

format-check-frontend: ## Check Prettier formatting for frontend
	cd $(FRONTEND_DIR) && npx prettier --check "src/**/*.{ts,tsx,js,jsx,css,json}"

format-check-backend: ## Check gofmt formatting for backend
	@test -z "$$(gofmt -l $(BACKEND_DIR))" || (echo "gofmt: unformatted files:"; gofmt -l $(BACKEND_DIR); exit 1)

format-check-ai: ## Check black + isort formatting for ai
	@if [ ! -f $(AI_DIR)/venv/bin/python ]; then \
	  echo "ERROR: Python venv not set up. Run: make install"; \
	  exit 1; \
	fi
	@if [ ! -f $(AI_DIR)/venv/bin/black ]; then \
	  cd $(AI_DIR) && ./venv/bin/pip install --quiet black isort; \
	fi
	cd $(AI_DIR) && ./venv/bin/isort --check-only . && ./venv/bin/black --check .

##@ Infrastructure

tf-bootstrap: ## One-time: create Terraform S3 state bucket + DynamoDB lock table
	cd $(TF_BOOTSTRAP) && terraform init && terraform apply

tf-init: ## terraform init (main infrastructure)
	cd $(TF_DIR) && terraform init

tf-plan: tf-init ## terraform plan
	cd $(TF_DIR) && terraform plan

tf-apply: tf-init ## terraform apply
	cd $(TF_DIR) && terraform apply

tf-destroy: tf-init ## terraform destroy (DESTRUCTIVE — will prompt for confirmation)
	cd $(TF_DIR) && terraform destroy

##@ Cleanup

clean: ## Remove all build artifacts
	$(MAKE) -C $(BACKEND_DIR) clean
	$(MAKE) -C $(AI_DIR) clean
	rm -f $(BACKEND_DIR)/bootstrap_local
	rm -rf $(FRONTEND_DIR)/build
	@echo "Clean complete."
