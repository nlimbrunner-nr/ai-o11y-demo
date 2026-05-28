"""
handler.py — AI car companion using Strands Agents + Bedrock AgentCore Memory.

Deployed as an AWS Lambda function via the Mangum adapter.
Entry point: handler.handler
"""

import json
import logging
import os
from typing import Optional

import httpx
from botocore.config import Config
from fastapi import FastAPI, HTTPException, Request
from mangum import Mangum
from pydantic import BaseModel
from starlette.middleware.cors import CORSMiddleware
from strands import Agent, tool
from strands.models import BedrockModel, CacheConfig

import graphql_client

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
COGNITO_USER_POOL_ID = os.environ.get("COGNITO_USER_POOL_ID", "")
COGNITO_CLIENT_ID = os.environ.get("COGNITO_CLIENT_ID", "")
COGNITO_REGION = os.environ.get("COGNITO_REGION", "us-east-1")

BEDROCK_REGION = os.environ.get("BEDROCK_REGION", "us-east-1")
BEDROCK_MODEL_ID = os.environ.get(
    "BEDROCK_MODEL_ID",
    "us.anthropic.claude-sonnet-4-6-20250514-v1:0",
)
AGENTCORE_MEMORY_ID = os.environ.get("AGENTCORE_MEMORY_ID", "")

# ---------------------------------------------------------------------------
# Optional AgentCore Memory integration
# ---------------------------------------------------------------------------
try:
    from bedrock_agentcore.memory.integrations.strands.config import (
        AgentCoreMemoryConfig,
    )
    from bedrock_agentcore.memory.integrations.strands.session_manager import (
        AgentCoreMemorySessionManager,
    )

    AGENTCORE_MEMORY_AVAILABLE = True
    logger.info("AgentCore Memory integration available")
except ImportError:
    AGENTCORE_MEMORY_AVAILABLE = False
    logger.info("AgentCore Memory not available — running without persistent memory")

# ---------------------------------------------------------------------------
# Bedrock model (module-level — reused across warm Lambda invocations)
# ---------------------------------------------------------------------------
_bedrock_model = BedrockModel(
    model_id=BEDROCK_MODEL_ID,
    region_name=BEDROCK_REGION,
    max_tokens=1024,
    boto_client_config=Config(
        retries={"max_attempts": 3, "mode": "adaptive"},
        connect_timeout=10,
        read_timeout=60,
    ),
    cache_config=CacheConfig(strategy="auto"),
)

_PROMPT_FILE = os.path.join(os.path.dirname(__file__), "system_prompt.txt")
SYSTEM_PROMPT = open(_PROMPT_FILE).read().strip()

# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(title="AI Chat Service", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------
class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None
    # auth_token / user_email are only used when running locally without API Gateway
    auth_token: Optional[str] = None
    user_email: Optional[str] = None


class ChatResponse(BaseModel):
    response: str


# ---------------------------------------------------------------------------
# Auth helpers
# ---------------------------------------------------------------------------


def _extract_identity(request: Request, body: "ChatRequest") -> tuple[str, str]:
    """
    Return (email, bearer_token) for this request.

    In production the API Gateway JWT authorizer has already validated the
    token before Lambda is invoked. The verified claims are injected into
    the Lambda event, which Mangum surfaces as request.scope["aws.event"].

    For local development (no API Gateway in front) the caller may pass
    auth_token / user_email in the request body as a fallback.
    """
    event = request.scope.get("aws.event", {})
    claims = (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("jwt", {})
        .get("claims", {})
    )

    email = claims.get("email") or body.user_email or ""
    if not email:
        raise HTTPException(status_code=401, detail="Could not determine user identity")

    auth_header = request.headers.get("Authorization", "")
    token = (
        auth_header.removeprefix("Bearer ")
        if auth_header.startswith("Bearer ")
        else body.auth_token or ""
    )
    if not token:
        raise HTTPException(status_code=401, detail="Missing bearer token")

    return email, token


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/chat", response_model=ChatResponse)
async def chat(raw_request: Request, request: ChatRequest):
    logger.info("Chat request received")

    email, auth_token = _extract_identity(raw_request, request)
    session_id = request.session_id or f"session-{email}"

    logger.info("User: %s, session: %s", email, session_id)

    # Build vehicle data tool as a closure so it captures the auth context
    # for this specific request without needing tool parameters.

    @tool
    def get_vehicle_data() -> str:
        """Fetch the current user's vehicle data including battery level, range, mileage, tire pressure, and service info."""
        data = graphql_client.query_user_vehicle_sync(email, auth_token)
        return json.dumps(data, indent=2) if data else "No vehicle data available."

    # Wire up AgentCore Memory when configured, otherwise run stateless
    session_manager = None
    if AGENTCORE_MEMORY_AVAILABLE and AGENTCORE_MEMORY_ID:
        session_manager = AgentCoreMemorySessionManager(  # type: ignore[possibly-undefined]
            agentcore_memory_config=AgentCoreMemoryConfig(  # type: ignore[possibly-undefined]
                memory_id=AGENTCORE_MEMORY_ID,
                session_id=session_id,
                actor_id=email,
            ),
            region_name=BEDROCK_REGION,
        )
        logger.info("Using AgentCore Memory: memory_id=%s", AGENTCORE_MEMORY_ID)
    else:
        logger.info("AGENTCORE_MEMORY_ID not set — running without persistent memory")

    agent = Agent(
        model=_bedrock_model,
        system_prompt=SYSTEM_PROMPT,
        tools=[get_vehicle_data],
        session_manager=session_manager,
        agent_id="car-companion",
    )

    try:
        result = agent(request.message)
        response_text = str(result)
        logger.info("Agent response generated, length=%d", len(response_text))
        return ChatResponse(response=response_text)
    except Exception as exc:
        logger.error("Agent invocation failed: %s", exc, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="An error occurred while processing your request. Please try again.",
        )


# ---------------------------------------------------------------------------
# Lambda entry point
# ---------------------------------------------------------------------------
handler = Mangum(app)
