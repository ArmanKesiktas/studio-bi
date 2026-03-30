from __future__ import annotations
from typing import Any, Optional
from pydantic import BaseModel


class KPICard(BaseModel):
    label: str
    value_column: str
    aggregation: str          # "sum" | "mean" | "count" | "max" | "min"
    computed_value: Any
    formatted_value: str


class ChartConfig(BaseModel):
    chart_id: str
    chart_type: str           # "line" | "bar" | "pie" | "scatter"
    title: str
    x_column: str
    y_column: str
    aggregation: str
    sort_order: int
    ai_explanation: str
    data: list[dict]          # aggregated, ready-to-render data points


class DashboardResponse(BaseModel):
    dataset_id: str
    kpi_cards: list[KPICard]
    charts: list[ChartConfig]
