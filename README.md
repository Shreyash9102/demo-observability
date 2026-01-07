Local demo: Observability stack (Loki, Prometheus, OTEL, Jaeger, Grafana)

Prerequisites:
- Docker and docker-compose installed

Run the stack:

```bash
cd demo-local-observability
docker compose up -d --build
```

Services and ports:
- Demo app: http://localhost:8080/
- Nginx sidecar (HTTPS): https://localhost:8443 (self-signed cert included)
- Prometheus: http://localhost:9090/
- Loki: http://localhost:3100/
- Promtail: (internal) pushes logs to Loki
- Jaeger UI: http://localhost:16686/
- Grafana: http://localhost:3000/ (admin:admin)

Verify logs:
- Trigger an endpoint that logs:

```bash
curl http://localhost:8080/
curl http://localhost:8080/error
```

- Check logs in Loki: http://localhost:3100/ (UI) or add Grafana datasource

Verify traces:
- Open Jaeger UI http://localhost:16686/ and search for service "demo-app"

Verify metrics:
- Prometheus: http://localhost:9090/targets (should show demo-app)
- Metrics endpoint: http://localhost:8080/metrics

Notes:
- This demo uses Promtail (to send /var/log/app.log to Loki) and OpenTelemetry Collector that forwards traces to Jaeger all-in-one for local simplicity.
- The stack mirrors the production flow: app -> local OTEL collector -> traces backend; app logs -> local log shipper -> Loki; app metrics -> Prometheus.
