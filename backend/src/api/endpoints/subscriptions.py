"""Subscription CRUD endpoints."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from src.models.schemas import (
    CreateSubscriptionRequest,
    SubscriptionListResponse,
    SubscriptionResponse,
    TaskListResponse,
    TaskResponse,
    UpdateSubscriptionRequest,
)
from src.services.subscription_service import SubscriptionService

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])
subscription_service = SubscriptionService()


@router.post("", response_model=SubscriptionResponse, status_code=201)
async def create_subscription(
    request: CreateSubscriptionRequest,
) -> SubscriptionResponse:
    """Create a new subscription."""
    return await subscription_service.create_subscription(request)


@router.get("", response_model=SubscriptionListResponse)
async def list_subscriptions() -> SubscriptionListResponse:
    """List all subscriptions."""
    return await subscription_service.get_subscription_list()


@router.get("/{sub_id}", response_model=SubscriptionResponse)
async def get_subscription(sub_id: str) -> SubscriptionResponse:
    """Get subscription by ID."""
    sub = await subscription_service.get_subscription(sub_id)
    if sub is None:
        raise HTTPException(status_code=404, detail="Subscription not found")
    return sub


@router.put("/{sub_id}", response_model=SubscriptionResponse)
async def update_subscription(
    sub_id: str, request: UpdateSubscriptionRequest
) -> SubscriptionResponse:
    """Update a subscription."""
    sub = await subscription_service.update_subscription(sub_id, request)
    if sub is None:
        raise HTTPException(status_code=404, detail="Subscription not found")
    return sub


@router.delete("/{sub_id}", status_code=204)
async def delete_subscription(sub_id: str) -> None:
    """Delete a subscription."""
    deleted = await subscription_service.delete_subscription(sub_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Subscription not found")


@router.get("/{sub_id}/tasks", response_model=TaskListResponse)
async def get_subscription_tasks(sub_id: str) -> TaskListResponse:
    """List tasks for a subscription."""
    return await subscription_service.get_subscription_tasks(sub_id)


@router.post("/{sub_id}/tasks", response_model=TaskResponse, status_code=201)
async def run_subscription_now(sub_id: str) -> TaskResponse:
    """Create a task immediately from an existing subscription."""
    task = await subscription_service.run_subscription_now(sub_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Subscription not found")
    return task
