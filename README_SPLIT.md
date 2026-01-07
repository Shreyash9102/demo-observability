Split stack instructions

1) Create a shared docker network (only once):

```bash
docker network create observability
```

2) Start central stack (Loki, Tempo, Grafana):

```bash
cd demo-local-observability
docker compose -f docker-compose.central.yml up -d
```

3) Start sidecar stack (app + sidecars):

```bash
docker compose -f docker-compose.sidecar.yml up -d --build
```

4) Verify:
- Grafana: http://localhost:3000 (admin/admin)
  - Add Loki datasource: URL http://loki:3100
  - Add Tempo datasource: Endpoint http://tempo:3200 (Tempo UI in Grafana)
- Loki API: http://localhost:3100
- App: https://localhost:8443 (via nginx sidecar)
- Prometheus: (not included in split demo; add if needed)

Notes:
- The sidecar services send logs to `loki:3100` and traces to `tempo:4318` via the shared network `observability`.
- If you change project names or use `docker compose -p`, ensure all services join the `observability` network.
