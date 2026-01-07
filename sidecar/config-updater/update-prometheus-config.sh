#!/bin/bash
set -e

# Config updater for Prometheus
# Watches for demo-app port changes and updates Prometheus config

DEMO_APP_HOST="demo-app"
DEMO_APP_PORT="8080"
PROMETHEUS_HOST="prometheus"
PROMETHEUS_PORT="9090"
PROMETHEUS_CONFIG_PATH="/etc/prometheus/prometheus.yml"
UPDATE_INTERVAL=10

echo "[$(date)] Starting Prometheus config updater..."

while true; do
  # Try to get demo-app container IP and port from Docker
  if command -v curl &> /dev/null; then
    # Get the docker host gateway (docker.host.internal or gateway)
    DOCKER_HOST="host.docker.internal"
    if ! nc -z "$DOCKER_HOST" 2375 2>/dev/null; then
      DOCKER_HOST="localhost"
    fi
    
    # Use docker socket to get container info
    if [ -S /var/run/docker.sock ]; then
      # Get demo-app container's network settings
      DEMO_APP_IP=$(curl -s --unix-socket /var/run/docker.sock http://localhost/containers/demo-app/json | grep -o '"IPAddress":"[^"]*' | cut -d'"' -f4 | head -1)
      
      if [ -n "$DEMO_APP_IP" ]; then
        echo "[$(date)] Found demo-app at $DEMO_APP_IP:$DEMO_APP_PORT"
        
        # Check if Prometheus config needs updating
        if ! grep -q "targets: \['$DEMO_APP_IP:$DEMO_APP_PORT'\]" "$PROMETHEUS_CONFIG_PATH" 2>/dev/null; then
          echo "[$(date)] Updating Prometheus config with demo-app at $DEMO_APP_IP:$DEMO_APP_PORT"
          
          # Update prometheus config
          sed -i "s/targets: \['[^']*:$DEMO_APP_PORT'\]/targets: ['$DEMO_APP_IP:$DEMO_APP_PORT']/g" "$PROMETHEUS_CONFIG_PATH"
          
          # Reload Prometheus via HTTP API
          if curl -s -X POST "http://$PROMETHEUS_HOST:$PROMETHEUS_PORT/-/reload" > /dev/null 2>&1; then
            echo "[$(date)] Prometheus config reloaded successfully"
          else
            echo "[$(date)] Warning: Could not reload Prometheus, config will be applied on restart"
          fi
        fi
      fi
    fi
  fi
  
  sleep $UPDATE_INTERVAL
done
