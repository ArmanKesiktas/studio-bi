from fastapi import APIRouter, HTTPException

from models.dashboard import DashboardResponse, KPICard, ChartConfig
from services import file_parser, profiler, dashboard_gen, gemini

router = APIRouter()


@router.get("/datasets/{dataset_id}/dashboard", response_model=DashboardResponse)
def get_dashboard(dataset_id: str):
    try:
        df = file_parser.load_parquet(dataset_id)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"Dataset bulunamadı: {dataset_id}")

    profile = profiler.profile_dataframe(df, dataset_id)
    result = dashboard_gen.generate_dashboard(df, profile)

    # Enrich charts with Gemini explanations
    enriched_charts = []
    for chart in result["charts"]:
        preview = chart["data"][:5]  # send only top 5 points to Gemini
        explanation = gemini.explain_chart(
            chart_config=chart,
            aggregated_result={"preview": preview},
        )
        enriched_charts.append(ChartConfig(
            chart_id=chart["chart_id"],
            chart_type=chart["chart_type"],
            title=chart["title"],
            x_column=chart["x_column"],
            y_column=chart["y_column"],
            aggregation=chart["aggregation"],
            sort_order=chart["sort_order"],
            ai_explanation=explanation,
            data=chart["data"],
        ))

    kpi_cards = [
        KPICard(
            label=k["label"],
            value_column=k["value_column"],
            aggregation=k["aggregation"],
            computed_value=k["computed_value"],
            formatted_value=k["formatted_value"],
        )
        for k in result["kpi_cards"]
    ]

    return DashboardResponse(
        dataset_id=dataset_id,
        kpi_cards=kpi_cards,
        charts=enriched_charts,
    )
