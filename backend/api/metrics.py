from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

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