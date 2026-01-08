from flask import Flask, request, jsonify
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
import logging
from pythonjsonlogger import jsonlogger
import time
import os

# OpenTelemetry instrumentation
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor

# Setup logging
logger = logging.getLogger("demo-app")
logHandler = logging.FileHandler('/var/log/app.log')
formatter = jsonlogger.JsonFormatter('%(asctime)s %(levelname)s %(name)s %(message)s')
logHandler.setFormatter(formatter)
logger.addHandler(logHandler)
logger.setLevel(logging.INFO)

# Prometheus metrics
REQUESTS = Counter('demo_app_requests_total', 'Total demo app requests', ['endpoint'])

# OpenTelemetry setup
resource = Resource.create({"service.name": "demo-app"})
provider = TracerProvider(resource=resource)
otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "otel-collector:4317")
otlp_exporter = OTLPSpanExporter(endpoint=otlp_endpoint)
provider.add_span_processor(BatchSpanProcessor(otlp_exporter))
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)

@app.route('/')
def index():
    with tracer.start_as_current_span("index-handler"):
        # attach trace_id to logs so Fluent Bit -> Loki shows trace linkage
        span = trace.get_current_span()
        span_ctx = span.get_span_context()
        trace_id = format(span_ctx.trace_id, '032x') if span_ctx and span_ctx.trace_id else None
        logger.info("handling index request", extra={"trace_id": trace_id})
        REQUESTS.labels(endpoint='/').inc()
        time.sleep(0.05)
        return jsonify({"status": "ok"})

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/error')
def error_handler():
    with tracer.start_as_current_span("error-handler"):
        span = trace.get_current_span()
        span_ctx = span.get_span_context()
        trace_id = format(span_ctx.trace_id, '032x') if span_ctx and span_ctx.trace_id else None
        logger.error("simulated error request", extra={"trace_id": trace_id})
        REQUESTS.labels(endpoint='/error').inc()
        return jsonify({"error": "simulated error"}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
