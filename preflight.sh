#!/bin/bash
# Setup validation script for observability stack

set -e

echo "======================================"
echo "Observability Stack - Pre-flight Check"
echo "======================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Docker
echo -n "Checking Docker... "
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    echo -e "${GREEN}✓${NC} Docker $DOCKER_VERSION"
else
    echo -e "${RED}✗${NC} Docker not found"
    exit 1
fi

# Check Docker Compose
echo -n "Checking Docker Compose... "
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version | grep -oP '\d+\.\d+\.\d+' | head -1)
    echo -e "${GREEN}✓${NC} Compose v$COMPOSE_VERSION"
else
    echo -e "${RED}✗${NC} Docker Compose not found"
    exit 1
fi

# Check required files
echo ""
echo "Checking configuration files..."
REQUIRED_FILES=(
    "docker-compose.yml"
    "loki-config.yaml"
    "tempo-config.yaml"
    "prometheus.yml"
    "app/app.py"
    "app/Dockerfile"
    "app/requirements.txt"
    "nginx/default.conf"
    "nginx/Dockerfile"
    "sidecar/fluent-bit/fluent-bit.conf"
    "sidecar/otel-collector-config.yaml"
)

MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${RED}✗${NC} $file (MISSING)"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    echo ""
    echo -e "${RED}Error: $MISSING_FILES required file(s) missing${NC}"
    exit 1
fi

# Check Docker Compose syntax
echo ""
echo -n "Validating docker-compose.yml... "
if docker compose config --quiet 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Valid"
else
    echo -e "${RED}✗${NC} Invalid syntax"
    exit 1
fi

# Check available ports
echo ""
echo "Checking required ports..."
PORTS=(
    "80:HTTP"
    "443:HTTPS"
    "3000:Grafana"
    "3100:Loki"
    "3200:Tempo"
    "4317:OTLP gRPC"
    "4318:OTLP HTTP"
    "8080:App"
    "8443:Nginx"
    "9090:Prometheus"
)

for port_info in "${PORTS[@]}"; do
    PORT=$(echo $port_info | cut -d':' -f1)
    NAME=$(echo $port_info | cut -d':' -f2)
    
    if ! lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Port $PORT ($NAME) - Available"
    else
        PROCESS=$(lsof -Pi :$PORT -sTCP:LISTEN -t 2>/dev/null || echo "unknown")
        echo -e "  ${YELLOW}⚠${NC} Port $PORT ($NAME) - Already in use (PID: $PROCESS)"
    fi
done

# Check system resources
echo ""
echo "Checking system resources..."
AVAILABLE_MEM=$(free -m | awk 'NR==2{printf("%.0f", $7)}')
echo -n "  Available memory: ${AVAILABLE_MEM}MB... "
if [ $AVAILABLE_MEM -gt 2048 ]; then
    echo -e "${GREEN}✓${NC} (Recommended: 4GB+)"
else
    echo -e "${YELLOW}⚠${NC} (Recommended: 4GB+)"
fi

echo ""
echo "======================================"
echo "Pre-flight checks completed!"
echo "======================================"
echo ""
echo "To start the stack, run:"
echo "  docker compose up -d --build"
echo ""
echo "To view logs:"
echo "  docker compose logs -f"
echo ""
echo "Services will be available at:"
echo "  - App: http://localhost:8080/"
echo "  - Grafana: http://localhost:3000/ (admin:admin)"
echo "  - Prometheus: http://localhost:9090/"
echo "  - Loki: http://localhost:3100/"
echo "  - Tempo: http://localhost:3200/"
echo ""
echo "For detailed instructions, see QUICKSTART.md"
echo ""
