"""Task CRUD endpoints."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from src.models.schemas import (
    CreateTaskRequest,
    PostListResponse,
    TaskListResponse,
    TaskResponse,
)
from src.services.task_service import NoAvailableSourcesError, get_task_service

router = APIRouter(prefix="/tasks", tags=["tasks"])
task_service = get_task_service()


@router.post("", response_model=TaskResponse, status_code=201)
async def create_task(request: CreateTaskRequest) -> TaskResponse:
    """Create a new analysis task."""
    try:
        return await task_service.create_task(request)
    except NoAvailableSourcesError as exc:
        raise HTTPException(status_code=422, detail=exc.as_detail()) from exc


@router.get("", response_model=TaskListResponse)
async def list_tasks() -> TaskListResponse:
    """List all tasks."""
    return await task_service.get_task_list()


@router.get("/{task_id}", response_model=TaskResponse)
async def get_task(task_id: str) -> TaskResponse:
    """Get task by ID."""
    task = await task_service.get_task(task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@router.delete("/{task_id}", status_code=204)
async def delete_task(task_id: str) -> None:
    """Delete a task."""
    deleted = await task_service.delete_task(task_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Task not found")


@router.get("/{task_id}/posts", response_model=PostListResponse)
async def get_task_posts(task_id: str, source: str | None = None) -> PostListResponse:
    """Get raw posts for a task."""
    return await task_service.get_task_posts(task_id, source)
