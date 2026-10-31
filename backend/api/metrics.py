from prometheus_client import Counter, Histogram, generate_latest
from prometheus_client import CONTENT_TYPE_LATEST

REQUEST_COUNT = Counter(
    "greenedge_api_requests_total",
    "Total API requests",
    ["method", "endpoint", "status"]
)

REQUEST_LATENCY = Histogram(
    "greenedge_api_request_duration_seconds",
    "API request duration"
)

def metrics_response():
    return generate_latest(), CONTENT_TYPE_LATEST