#!/bin/bash

echo "=========================================="
echo "Social App Server Deployment Script"
echo "=========================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing..."
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose..."
    mkdir -p ~/.docker/cli-plugins
    curl -SL https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
fi

echo ""
echo "Building and starting services..."
echo ""

# Stop existing containers
docker compose down

# Build and start
docker compose up -d --build

echo ""
echo "Waiting for services to be ready..."
sleep 10

# Check status
echo ""
echo "Service Status:"
docker compose ps

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Services:"
echo "  - API Server: http://localhost:8080"
echo "  - MinIO Console: http://localhost:9001"
echo "    (Username: minioadmin, Password: minioadmin)"
echo ""
echo "Useful Commands:"
echo "  - View logs: docker compose logs -f server"
echo "  - Stop all: docker compose down"
echo "  - Restart: docker compose restart"
echo ""