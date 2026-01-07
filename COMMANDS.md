# Command Reference - Observability Stack

## Quick Start Commands

```bash
# Navigate to project
cd /opt/demo-observability

# Build and start all services
docker compose up -d --build

# View logs (all services)
docker compose logs -f

# View logs for specific service
docker compose logs -f demo-app
docker compose logs -f fluent-bit
docker compose logs -f otel-collector

# Stop all services
docker compose down

# Remove all data
docker compose down -v

# Restart specific service
docker compose restart demo-app
```

## Generate Sample Data

```bash
# Via app directly (HTTP)
curl http://localhost:8080/
curl http://localhost:8080/error
curl http://localhost:8080/metrics

# Via Nginx sidecar (HTTPS)
curl -k https://localhost:8443/
curl -k https://localhost:8443/error

# Generate multiple requests (for metrics aggregation)
for i in {1..10}; do curl http://localhost:8080/; done
for i in {1..5}; do curl http://localhost:8080/error; done
```

## Access UI Dashboards

### Grafana (Logs, Traces, Metrics)
```bash
# Open in browser or use curl
curl http://localhost:3000/

# Login: admin / admin
```

### Prometheus (Metrics Query)
```bash
curl http://localhost:9090/

# Query metrics
curl 'http://localhost:9090/api/v1/query?query=demo_app_requests_total'
```

### Loki (Log Query)
```bash
# API query
curl 'http://localhost:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="demo-app"}' \
  --data-urlencode 'start=1h'
```

### Tempo (Trace Query)
```bash
# List services
curl http://localhost:3200/api/search?service=demo-app

# Get traces for service
curl 'http://localhost:3200/api/search?service=demo-app&tags=http.status_code=200'
```

## Inspect Container Status

```bash
# List all containers
docker compose ps

# Show container details
docker inspect demo-app
docker inspect fluent-bit
docker inspect otel-collector

# Get container IP
docker inspect -f '{{.NetworkSettings.IPAddress}}' demo-app

# Get environment variables
docker exec demo-app env | grep OTEL
```

## Check Data Flows

### Verify Logs Reaching Loki
```bash
# Check app is writing logs
docker exec demo-app tail -f /var/log/app.log

# Check fluent-bit is reading logs
docker compose logs fluent-bit | grep "tail\|OUTPUT"

# Query Loki directly
curl 'http://localhost:3100/loki/api/v1/label/job/values'

# Count log entries
curl 'http://localhost:3100/loki/api/v1/query_range' \
  --data-urlencode 'query=count_over_time({job="demo-app"}[5m])'
```

### Verify Traces Reaching Tempo
```bash
# Check OTEL collector is receiving spans
docker compose logs otel-collector | grep "trace\|span"

# Query Tempo for traces
curl 'http://localhost:3200/api/traces?service=demo-app' | jq '.traces | length'

# Get specific trace details
curl 'http://localhost:3200/api/traces/<trace-id>' | jq '.'
```

### Verify Metrics Reaching Prometheus
```bash
# Check app metrics endpoint
curl http://localhost:8080/metrics

# Check Prometheus scrape status
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[]'

# Query metrics
curl 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=demo_app_requests_total'
```

## Debug Individual Services

### Demo App
```bash
# View app logs
docker compose logs demo-app

# Execute command in container
docker compose exec demo-app python -c "import flask; print(flask.__version__)"

# View app config
docker compose exec demo-app env | sort

# Check metrics endpoint
docker exec demo-app curl -s http://localhost:8080/metrics | head -20
```

### Fluent Bit
```bash
# View logs
docker compose logs fluent-bit

# Check file being monitored
docker exec fluent-bit ls -la /var/log/

# Validate config
docker exec fluent-bit /fluent-bit/bin/fluent-bit -c /fluent-bit/etc/fluent-bit.conf --dry-run
```

### OTEL Collector
```bash
# View logs
docker compose logs otel-collector

# Check receiver status
docker exec otel-collector curl -s http://localhost:8888/metrics | grep receiver

# Test OTLP endpoint
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/protobuf" \
  -d "" 2>&1 | head
```

### Nginx Sidecar
```bash
# View logs
docker compose logs nginx-sidecar

# Test HTTP redirect
curl -v http://localhost/

# Test HTTPS (with self-signed cert)
curl -vk https://localhost:8443/

# Check certificate
echo | openssl s_client -connect localhost:8443 2>/dev/null | grep -A5 "Certificate"
```

## Performance & Monitoring

```bash
# Check CPU and memory usage
docker compose stats

# Watch stats in real-time
docker compose stats --no-stream=false

# Get disk usage
docker compose exec loki du -sh /loki
docker compose exec tempo du -sh /var/tempo
docker compose exec prometheus du -sh /prometheus

# Count log entries in Loki
curl 'http://localhost:3100/loki/api/v1/query' \
  --data-urlencode 'query=count by (job) ({job=~".+"})'
```

## Advanced Queries

### Loki - Find errors in logs
```bash
curl 'http://localhost:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="demo-app"} |= "error"' \
  --data-urlencode 'start=1h' | jq '.data.result[].values'
```

### Prometheus - Request rate
```bash
curl 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=rate(demo_app_requests_total[5m])'
```

### Prometheus - Error rate
```bash
curl 'http://localhost:9090/api/v1/query' \
  --data-urlencode 'query=rate(demo_app_requests_total{endpoint="/error"}[5m])'
```

### Tempo - Traces with errors
```bash
curl 'http://localhost:3200/api/search?service=demo-app&tags=status=unset'
```

## Cleanup & Reset

```bash
# Remove all containers (keep data volumes)
docker compose down

# Remove all containers and data
docker compose down -v

# Clean up all unused Docker resources
docker system prune -a

# Rebuild images
docker compose build --no-cache

# Full reset (remove volumes AND images)
docker compose down -v --rmi all
```

## Useful Aliases

Add to your `.bashrc` or `.zshrc`:

```bash
alias demo-up='cd /opt/demo-observability && docker compose up -d --build'
alias demo-down='cd /opt/demo-observability && docker compose down'
alias demo-logs='cd /opt/demo-observability && docker compose logs -f'
alias demo-app-logs='cd /opt/demo-observability && docker compose logs -f demo-app'
alias demo-ps='cd /opt/demo-observability && docker compose ps'
alias demo-test='curl http://localhost:8080/ && curl http://localhost:8080/error && curl http://localhost:8080/metrics'
```

## Tips & Tricks

1. **Watch multiple containers**: `docker compose logs -f demo-app fluent-bit otel-collector`
2. **Pretty JSON output**: Pipe to `| jq '.'`
3. **Monitor specific pattern**: `docker compose logs -f | grep "error\|ERROR"`
4. **Export logs**: `docker compose logs > stack.log`
5. **Search within logs**: `docker compose logs | grep "pattern"`
6. **Get last N lines**: `docker compose logs demo-app --tail=50`
7. **Filter by time**: `docker compose logs --since 5m`

## Environment Variables

```bash
# In docker-compose.yml, these are set for the app:
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_SERVICE_NAME=demo-app

# To modify:
docker compose exec demo-app env
```

## Network Inspection

```bash
# List all networks
docker network ls

# Inspect observability network
docker network inspect observability

# Get service IP
docker inspect -f '{{.NetworkSettings.Networks.observability.IPAddress}}' demo-app

# Test DNS resolution between services
docker compose exec demo-app getent hosts otel-collector
```

## File Inspection

```bash
# View fluent-bit config
cat /opt/demo-observability/sidecar/fluent-bit/fluent-bit.conf

# View OTEL config
cat /opt/demo-observability/sidecar/otel-collector-config.yaml

# View Loki config
cat /opt/demo-observability/loki-config.yaml

# View Tempo config
cat /opt/demo-observability/tempo-config.yaml
```
