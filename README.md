# Demo Observability Stack - Local Development

A comprehensive observability platform demonstrating the sidecar pattern with Loki (logs), Prometheus (metrics), and Tempo (traces), all visualized in Grafana.

## Overview

This project shows a production-ready architecture for observability:

- **Logging**: Application logs (JSON format) → Fluent Bit → Loki
- **Metrics**: Application metrics → Prometheus → Grafana  
- **Tracing**: Application traces (OTEL instrumentation) → OTEL Collector → Tempo → Grafana
- **API Gateway**: Nginx sidecar provides SSL/TLS termination and request proxying

## Architecture Highlights

- **Sidecar Pattern**: Nginx API gateway + Fluent Bit log router deployed alongside the app
- **OpenTelemetry Instrumentation**: Flask app auto-instrumented with OTEL
- **Self-contained**: All components (Loki, Tempo, Prometheus, Grafana) included
- **Production-ready**: Follows observability best practices

## Prerequisites

- Docker and Docker Compose installed
- ~4GB available RAM

## Quick Start

```bash
cd /opt/demo-observability
docker compose up -d --build
```

Wait for services to start (~30-60 seconds):

```bash
docker compose logs -f
```

### Access Services

| Service | URL | Purpose |
|---------|-----|---------|
| Demo App | http://localhost:8080/ | Test the application |
| API Gateway (HTTPS) | https://localhost:8443/ | Secure proxy endpoint |
| Grafana | http://localhost:3000/ | Dashboards & visualization (admin:admin) |
| Prometheus | http://localhost:9090/ | Metrics exploration |
| Loki | http://localhost:3100/ | Log aggregation |
| Tempo | http://localhost:3200/ | Trace backend |

## Generate Sample Data

```bash
# Successful request
curl http://localhost:8080/
curl https://localhost:8443/ -k

# Error request  
curl http://localhost:8080/error
curl https://localhost:8443/error -k

# View metrics
curl http://localhost:8080/metrics
```

## Verify Observability Data

### View Logs in Grafana
1. Open http://localhost:3000 (admin:admin)
2. Go to **Explore** 
3. Select **Loki** datasource
4. Query: `{job="demo-app"}`

### View Traces in Grafana
1. In **Explore** select **Tempo** datasource
2. Search for service: `demo-app`
3. Click on any trace to see spans and details

### View Metrics in Prometheus
1. Open http://localhost:9090
2. Query: `demo_app_requests_total` or `rate(demo_app_requests_total[5m])`

## Troubleshooting

Check app logs:
```bash
docker compose logs demo-app
```

Check fluent-bit is collecting logs:
```bash
docker compose logs fluent-bit
```

Check OTEL collector:
```bash
docker compose logs otel-collector
```

View app logs directly:
```bash
docker compose exec demo-app tail -f /var/log/app.log
```

## Configuration Files

- **App**: [app/app.py](app/app.py) - Flask app with OTEL instrumentation
- **Nginx**: [nginx/default.conf](nginx/default.conf) - API gateway config
- **Fluent Bit**: [sidecar/fluent-bit/fluent-bit.conf](sidecar/fluent-bit/fluent-bit.conf) - Log collection
- **OTEL**: [sidecar/otel-collector-config.yaml](sidecar/otel-collector-config.yaml) - Trace collection
- **Prometheus**: [prometheus.yml](prometheus.yml) - Metrics scraping
- **Loki**: [loki-config.yaml](loki-config.yaml) - Log retention & storage
- **Tempo**: [tempo-config.yaml](tempo-config.yaml) - Trace storage & retention

## Data Retention

- **Logs (Loki)**: 24 hours (configurable in loki-config.yaml)
- **Traces (Tempo)**: 24 hours (configurable in tempo-config.yaml)
- **Metrics (Prometheus)**: 15 days (configurable in prometheus.yml)

## Cleanup

```bash
# Stop services
docker compose down

# Remove all data
docker compose down -v
```

## For Detailed Setup Guide

See [QUICKSTART.md](QUICKSTART.md) for:
- Architecture diagram
- Component-by-component verification
- Advanced configuration options
- Data flow explanations
- Development workflows

## Key Features

✅ **Complete Observability**: Logs, metrics, and traces from single app  
✅ **Sidecar Pattern**: Production-like architecture with proxies and sidecars  
✅ **OTEL Native**: OpenTelemetry instrumentation ready  
✅ **Self-signed HTTPS**: Nginx with SSL/TLS out of the box  
✅ **Grafana Integration**: Pre-configured datasources for Loki, Tempo, Prometheus  
✅ **Local Development**: Everything runs locally, no external dependencies  

## Notes

- Uses self-signed certificates for HTTPS (use `-k` with curl to skip verification)
- Default Grafana credentials: `admin:admin` (change in production)
- All data stored in Docker volumes (ephemeral on `docker compose down -v`)
