"""Compute the next run time of a cron expression. See TASK.md."""
from datetime import datetime


def next_run(expr: str, after: datetime) -> datetime:
    raise NotImplementedError
