"""Analysis result endpoints."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from src.models.schemas import AnalysisReportResponse
from src.services.task_service import TaskService

router = APIRouter(prefix="/tasks", tags=["analysis"])
task_service = TaskService()


@router.get("/{task_id}/report", response_model=AnalysisReportResponse)
async def get_report(task_id: str) -> AnalysisReportResponse:
    """Get analysis report for a task."""
    report = await task_service.get_task_report(task_id)
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    return report
