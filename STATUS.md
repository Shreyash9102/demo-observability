# Local Observability Demo - Status Report

**Date**: 2026-01-08  
**Status**: Operational (Traces query issue under investigation)

## Component Status

### Central Stack (docker-compose.central.yml)

- ✅ **Loki** (2.8.2): Running, receiving logs from Fluent-bit
  - HTTP: `localhost:3100`
  - Storage: `/loki/index` (boltdb), `/loki/chunks` (filesystem), no WAL
  - Config: Single-process mode, in-memory KV store

- ✅ **Tempo** (2.3.1): Running, receiving OTLP traces
  - HTTP: `localhost:3200`
  - gRPC: `0.0.0.0:9095` (internal)
  - OTLP Receiver: HTTP on `0.0.0.0:4318`, gRPC on `0.0.0.0:4317`
  - Storage: `/var/tempo/blocks` (local filesystem)
  - Config: Single-binary mode (query-frontend worker disabled to prevent RPC conflicts)

- ✅ **Grafana** (9.5.2): Running with provisioned datasources
  - HTTP: `localhost:3000` (admin/admin)
  - Datasources: Loki (uid: loki), Tempo (uid: tempo), Prometheus (uid: prometheus)

- ✅ **Prometheus** (v2.45.0): Running, scraping metrics
  - HTTP: `localhost:9090`
  - Targets: `demo-app:8080` (health: up)

### Sidecar Stack (docker-compose.sidecar.yml)

- ✅ **demo-app** (Python 3.11 + Gunicorn): Running
  - HTTP: `localhost:8080` (app) + `:8080/metrics` (Prometheus metrics)
  - Endpoints: `/` (200), `/metrics` (Prometheus format), `/error` (500 with spans)
  - Logs: JSON format to `/var/log/app.log` (instrumented with trace IDs)
  - Traces: OTLP HTTP to `http://172.18.0.4:4318/v1/traces` (Tempo)

- ✅ **nginx-sidecar**: Running (reverse proxy, TLS certs generated)
  - Ports: 80, 443 (not exposed in compose)

- ✅ **Fluent-bit** (2.1.8): Running, tailing logs
  - Config: Tail input on `/var/log/app.log`
  - Output: Loki with labels `job=demo-app, env=local`

- ✅ **otel-collector** (0.85.0): Running
  - OTLP Receiver: gRPC 4317, HTTP 4318
  - Config: Ready but **not receiving traces directly** (app sends to Tempo)
  - Note: Can be used to process traces centrally if needed

- ✅ **config-updater**: Running (updates Prometheus config based on detected services)

## Data Flow Verification

### Logs: App → Fluent-bit → Loki ✅
```
docker exec demo-app python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/')"
curl -s 'http://localhost:3100/loki/api/v1/labels'
# Returns: {"status":"success","data":["env","job"]}
```

### Metrics: App → Prometheus ✅
```
curl -s http://localhost:9090/api/v1/targets
# demo-app:8080 is 'up'
```

### Traces: App → Tempo ✅
```
# After generating 3+ requests, check ingestion counter:
curl -s http://localhost:3200/metrics | grep tempo_distributor_traces_per_batch_count
# Output: tempo_distributor_traces_per_batch_count 1 (or higher)
```

## Known Issues & Resolutions

### Issue 1: Tempo RPC Errors (RESOLVED)
**Error**: "http2: frame too large" / "error contacting frontend"  
**Root Cause**: Query-frontend worker trying to communicate on HTTP port instead of gRPC  
**Resolution**: Disabled query-frontend worker in `central/tempo-config.yaml` for single-binary mode

### Issue 2: DNS Resolution Between Compose Stacks (RESOLVED)
**Error**: demo-app couldn't resolve "tempo" hostname  
**Root Cause**: Docker's embedded DNS doesn't work across compose stacks on external networks  
**Resolution**: Using direct IP address in OTLP endpoint: `http://172.18.0.4:4318/v1/traces`

### Issue 3: Missing OTLP Path (RESOLVED)
**Error**: "404 page not found" when traces exported  
**Root Cause**: OTLP HTTP endpoint requires `/v1/traces` path  
**Resolution**: Updated `OTEL_EXPORTER_OTLP_ENDPOINT` to include full path

### Issue 4: Traces Query Returns Empty (OPEN)
**Status**: Traces are ingested (counter increments) but query returns empty results  
**Hypothesis**: Trace blocks may need time to finalize or query API needs adjustment  
**Next Steps**: Monitor Tempo logs for block finalization, check if query needs explicit time range

## Configuration Files

- `docker-compose.central.yml` - Central observability stack (Loki, Tempo, Grafana, Prometheus)
- `docker-compose.sidecar.yml` - Sidecar stack (app, sidecars, collectors)
- `central/loki-config.yaml` - Loki local single-process config
- `central/tempo-config.yaml` - Tempo local single-binary config (with query-frontend worker disabled)
- `sidecar/otel-collector-config.yaml` - OpenTelemetry Collector config (passive, ready if needed)
- `sidecar/fluent-bit/fluent-bit.conf` - Fluent-bit log tail and Loki output config
- `app/app.py` - Flask demo app with OTLP instrumentation

## Running the Demo

### Start Central Stack
```bash
cd /Users/shreyashhagwane/Downloads/Elimu/Actual_dir/demo-local-observability

# Create observability network
docker network create observability --driver bridge

# Start central services
docker compose -f docker-compose.central.yml up -d
```

### Start Sidecar Stack
```bash
# Start sidecars (connects to observability network)
docker compose -f docker-compose.sidecar.yml up -d
```

### Generate Test Data
```bash
# Generate logs and traces
for i in {1..10}; do
  docker exec demo-app python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/')"
  sleep 0.5
done

# Generate error traces
docker exec demo-app python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/error')"
```

### View in Grafana
- **Logs**: http://localhost:3000 → Explore → Select Loki datasource → `{job="demo-app"}`
- **Metrics**: http://localhost:3000 → Explore → Select Prometheus → `demo_app_requests_total`
- **Traces**: http://localhost:3000 → Explore → Select Tempo → Search service "demo-app"

## Network Details

- **External Network**: `observability`
  - Loki: `172.18.0.3:3100`
  - Tempo: `172.18.0.4:3200` (HTTP), `172.18.0.4:4317` (OTLP gRPC), `172.18.0.4:4318` (OTLP HTTP)
  - Grafana: `172.18.0.5:3000`
  - Prometheus: `172.18.0.6:9090`
  - demo-app: `172.18.0.9:8080`
  - otel-collector: `172.18.0.8:4317-4318`
  - fluent-bit, nginx-sidecar: also on network

## Performance Notes

- **Loki**: Single-process, in-memory KV - suitable for local development only
- **Tempo**: Local filesystem blocks, no distributed mode - suitable for demo/testing
- **Prometheus**: 15-day retention (configurable in docker-compose.central.yml)
- **Trace Retention**: Default (24 hours, configurable)

## Next Steps

1. **Trace Querying**: Investigate why query returns empty despite ingestion success
   - Check Tempo internal logs for block finalization
   - Try explicit time range in query
   - Check if Tempo needs cache warmed

2. **Dashboards**: Create Grafana dashboards for logs, metrics, and traces

3. **Production Hardening**:
   - Enable WAL for Loki and Tempo
   - Configure persistent volumes
   - Add health checks to compose files
   - Implement proper retention policies

4. **Integration Testing**: Add automated tests to verify end-to-end data flow
