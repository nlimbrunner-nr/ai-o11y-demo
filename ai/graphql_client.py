"""GraphQL client for querying vehicle data from the backend API."""

import logging
import os
from typing import Any, Dict, Optional

import httpx
from httpx import Client

logger = logging.getLogger(__name__)

GRAPHQL_API_URL = os.environ.get("GRAPHQL_API_URL", "http://localhost:4000/graphql")

_USER_VEHICLE_QUERY = """
query GetUser($email: String!) {
    user(email: $email) {
        email
        name
        vehicle {
            id
            model
            batteryLevel
            rangeKm
            totalKm
            nextServiceKm
            tirePressure
            softwareVersion
            isLocked
            lastUpdated
        }
    }
}
"""


async def query_user_vehicle(email: str, auth_token: str) -> Dict[str, Any]:
    """
    Query the GraphQL backend for the authenticated user's vehicle data.

    Args:
        email: The user's email address (used as the query variable).
        auth_token: The raw JWT bearer token to forward to the backend.

    Returns:
        The ``data.user`` dict from the GraphQL response, or an empty dict
        when the user/vehicle cannot be found or an error occurs.
    """
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {auth_token}",
    }
    payload = {
        "query": _USER_VEHICLE_QUERY,
        "variables": {"email": email},
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                GRAPHQL_API_URL,
                json=payload,
                headers=headers,
            )
            response.raise_for_status()
            body = response.json()

        if "errors" in body:
            logger.warning(
                "GraphQL returned errors for email=%s: %s", email, body["errors"]
            )
            return {}

        user_data = body.get("data", {}).get("user") or {}
        return user_data

    except httpx.HTTPStatusError as exc:
        logger.error(
            "GraphQL backend returned HTTP %s: %s",
            exc.response.status_code,
            exc.response.text,
        )
        return {}
    except httpx.RequestError as exc:
        logger.error("GraphQL request failed: %s", exc)
        return {}
    except Exception as exc:
        logger.error("Unexpected error querying GraphQL: %s", exc, exc_info=True)
        return {}


def query_user_vehicle_sync(email: str, auth_token: str) -> Dict[str, Any]:
    """
    Synchronous version of query_user_vehicle for use in Strands tools.

    Strands @tool functions run synchronously, so we use httpx.Client
    instead of httpx.AsyncClient here.
    """
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {auth_token}",
    }
    payload = {
        "query": _USER_VEHICLE_QUERY,
        "variables": {"email": email},
    }

    try:
        with Client(timeout=10.0) as client:
            response = client.post(GRAPHQL_API_URL, json=payload, headers=headers)
            response.raise_for_status()
            body = response.json()

        if "errors" in body:
            logger.warning(
                "GraphQL returned errors for email=%s: %s", email, body["errors"]
            )
            return {}

        return body.get("data", {}).get("user") or {}

    except httpx.HTTPStatusError as exc:
        logger.error(
            "GraphQL backend returned HTTP %s: %s",
            exc.response.status_code,
            exc.response.text,
        )
        return {}
    except httpx.RequestError as exc:
        logger.error("GraphQL sync request failed: %s", exc)
        return {}
    except Exception as exc:
        logger.error("Unexpected error in sync GraphQL query: %s", exc, exc_info=True)
        return {}
