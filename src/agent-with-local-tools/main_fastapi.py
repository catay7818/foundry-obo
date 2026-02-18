"""
FastAPI server for Foundry OBO Agent data query endpoint.
"""

from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel, Field
from dotenv import load_dotenv

load_dotenv(override=True)


from query_data import query_data_on_behalf_of_user

app = FastAPI(
    title="Foundry OBO Agent API",
    description="API for querying data on behalf of users",
    version="1.0.0",
)


class QueryRequest(BaseModel):
    """Request model for data query."""

    container: str = Field(
        ...,
        description="The name of the container to query (Finance, HR, or Sales)",
        examples=["Finance", "HR", "Sales"],
    )
    query: str | None = Field(
        None,
        description="Optional SQL query to filter data. If not provided, returns all data.",
        examples=["SELECT * FROM c WHERE c.amount > 1000"],
    )


@app.post("/query")
async def query_data(
    request: QueryRequest,
    authorization: str = Header(..., description="Bearer token for authentication"),
):
    """
    Query data from a container on behalf of the current user.

    Args:
        request: QueryRequest containing container name and optional query
        authorization: Authorization header with bearer token

    Returns:
        JSON response with query results or error message

    Raises:
        HTTPException: If the query fails or authorization header is missing
    """
    result = await query_data_on_behalf_of_user(
        container=request.container,
        query=request.query,
        bearer_token=authorization,
    )

    # Check if the result indicates an error
    if isinstance(result, dict):
        if result.get("success") is False:
            # Determine appropriate HTTP status code based on error
            error_msg = result.get("error", "Unknown error")
            if "Unauthorized" in error_msg:
                raise HTTPException(status_code=401, detail=error_msg)
            elif "Forbidden" in error_msg:
                raise HTTPException(status_code=403, detail=error_msg)
            elif "Not found" in error_msg:
                raise HTTPException(status_code=404, detail=error_msg)
            elif "timeout" in error_msg.lower():
                raise HTTPException(status_code=504, detail=error_msg)
            else:
                raise HTTPException(status_code=500, detail=error_msg)

    return result
