# AI O11y Automotive Demo

A car companion app that demonstrates AI observability patterns using AWS Bedrock, Strands Agents, and AgentCore Memory. Users authenticate via Cognito and chat with an AI assistant that has live access to their vehicle data.

https://nlimbrunner-nr.github.io/ai-o11y-demo/

---

## Architecture

```
GitHub Pages (React SPA)
        │  GraphQL + REST
        ▼
API Gateway (HTTP)
   ├──► Lambda: AI Chat (Python / Strands Agents)   ◄── Bedrock (Claude Sonnet 4.6)
   └──► Lambda: GraphQL Data (Go / gqlgen)                   │
                                                   AgentCore Memory (optional)
   Cognito (JWT auth, admin-only user creation)
```

All AWS infrastructure is provisioned via **Terraform** and deployed via **GitHub Actions** using OIDC (no stored AWS keys).

---

## Components

### Frontend — `frontend/`

**Stack:** React + TypeScript + Material UI + Apollo Client  
**Hosting:** GitHub Pages (deployed on push to `main`)

- Cognito sign-in via AWS Amplify
- Vehicle stats panel: battery, range, odometer, lock status, tire pressure
- Live chat window (`ChatPanel.tsx`) — POSTs to the AI Lambda
- Apollo Client polls the GraphQL Lambda every 30 seconds

**Environment variables** (set automatically by `deploy-infra.yml`, or see `frontend/.env.example`):

| Variable | Description |
|---|---|
| `REACT_APP_API_URL` | API Gateway base URL |
| `REACT_APP_COGNITO_USER_POOL_ID` | Cognito User Pool ID |
| `REACT_APP_COGNITO_CLIENT_ID` | Cognito App Client ID |
| `REACT_APP_COGNITO_REGION` | AWS region |
| `REACT_APP_COGNITO_DOMAIN` | Cognito hosted UI domain |

---

### AI Chat Backend — `ai/`

**Stack:** Python 3.12, FastAPI, Mangum, [Strands Agents SDK](https://strandsagents.com)  
**Model:** `claude-sonnet-4-6` via AWS Bedrock  
**Deployment:** AWS Lambda (arm64, 512 MB, 60 s timeout)

- `POST /chat` — accepts `{ message, conversation_history, auth_token, user_email }`
- Validates the Cognito JWT via JWKS
- Builds a Strands `Agent` with a `get_vehicle_data` tool; the agent calls the tool on demand to fetch live vehicle data from the GraphQL backend
- Uses Bedrock prompt caching (`CacheConfig(strategy="auto")`) to reduce latency and cost on repeated system prompts
- **AgentCore Memory** (optional): if `AGENTCORE_MEMORY_ID` is set, persistent conversation history is stored via `bedrock-agentcore`; otherwise stateless

---

### GraphQL Data Backend — `backend/`

**Stack:** Go 1.22, gqlgen  
**Deployment:** AWS Lambda (arm64, `provided.al2023`, 128 MB)  
**Data store:** `backend/data/users.json` — no database

```graphql
type Query {
  user(email: String!): User
}

type User {
  email:   String!
  name:    String!
  vehicle: Vehicle!
}

type Vehicle {
  id               ID!
  model            String!
  batteryLevel     Int!
  rangeKm          Int!
  totalKm          Int!
  nextServiceKm    Int!
  tirePressure     Float!
  softwareVersion  String!
  isLocked         Boolean!
  lastUpdated      String!
}
```

---

### Auth — Cognito

- User Pool with email as username; self-signup disabled (`allow_admin_create_user_only = true`)
- App client for the frontend (no secret, SRP auth flow)
- Add users manually: `aws cognito-idp admin-create-user --user-pool-id <id> --username <email>`

---

### Infrastructure — `terraform/`

```
terraform/
  main.tf          — provider config, S3/DynamoDB remote state backend
  cognito.tf       — user pool + app client
  lambda.tf        — both Lambda functions + IAM roles
  api_gateway.tf   — HTTP API Gateway with Cognito authorizer
  iam.tf           — OIDC role for GitHub Actions
  outputs.tf       — API URL, Cognito IDs (exported to GitHub Actions vars)
  bootstrap/       — one-time S3 bucket + DynamoDB table for Terraform state
```

The `deploy-infra.yml` workflow runs `terraform apply` and automatically writes all outputs as GitHub Actions repository variables, so the frontend deploy picks them up without manual configuration.

---

## GitHub Actions Workflows

| Workflow | Trigger | What it does |
|---|---|---|
| `deploy-infra.yml` | push to `main` (terraform/**) | `terraform apply` → exports outputs as repo vars |
| `deploy-frontend.yml` | push to `main` (frontend/**) | `npm run build` → GitHub Pages |
| `deploy-ai.yml` | push to `main` (ai/**) | builds Python zip → updates Lambda |
| `deploy-backend.yml` | push to `main` (backend/**) | builds Go binary → updates Lambda |

---

## Setup

### Prerequisites

- AWS account with Bedrock model access for `claude-sonnet-4-6` in `us-east-1`
- Terraform ≥ 1.6
- Go 1.22+, Python 3.12+, Node 18+

### 1. Bootstrap Terraform state (one-time)

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

Creates the S3 bucket and DynamoDB table used for remote state.

### 2. Push to `main`

Add `AWS_ACCOUNT_ID` as a GitHub Actions secret, then push. The four workflows deploy everything in dependency order. After `deploy-infra.yml` completes, Cognito and API Gateway values are available as repository variables for subsequent runs.

### 3. Add users

```bash
aws cognito-idp admin-create-user \
  --user-pool-id <pool-id> \
  --username user@example.com \
  --temporary-password "Temp1234!" \
  --message-action SUPPRESS
```

### Optional: AgentCore Memory

To enable persistent conversation memory across sessions, create an AgentCore Memory resource and pass its ID as a Terraform variable:

```bash
terraform apply -var="agentcore_memory_id=<memory-id>"
```

---

## Folder Structure

```
.
├── frontend/          # React SPA (GitHub Pages)
│   └── public/images/ # Vehicle images
├── ai/                # Python AI chat Lambda (Strands Agents)
├── backend/           # Go GraphQL Lambda (gqlgen)
│   └── data/
│       └── users.json # Static user + vehicle data
└── terraform/         # All AWS infrastructure
    └── bootstrap/     # One-time state backend setup
```
