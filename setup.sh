#!/bin/bash

set -e

echo "=== Blue/Green Deployment Setup ==="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi
echo "✅ Docker found: $(docker --version)"

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi
echo "✅ Docker Compose found: $(docker-compose --version)"

# Check if .env exists
if [ ! -f .env ]; then
    echo ""
    echo "⚠️  .env file not found. Creating template..."
    cat > .env << 'EOF'
# Application Images (REQUIRED - Update these!)
BLUE_IMAGE=your-registry/blue-app:latest
GREEN_IMAGE=your-registry/green-app:latest

# Active Pool Configuration
ACTIVE_POOL=blue

# Release IDs
RELEASE_ID_BLUE=v1.0.0-blue
RELEASE_ID_GREEN=v1.0.0-green

# Application Port
PORT=3000
EOF
    echo "✅ Created .env template"
    echo ""
    echo "⚠️  IMPORTANT: Please update .env with your actual image references!"
    echo "   Edit .env and set BLUE_IMAGE and GREEN_IMAGE values."
    exit 0
fi

echo "✅ .env file found"

# Validate .env
echo ""
echo "Validating .env configuration..."

source .env

if [ -z "$BLUE_IMAGE" ] || [ "$BLUE_IMAGE" = "your-registry/blue-app:latest" ]; then
    echo "❌ BLUE_IMAGE not configured in .env"
    exit 1
fi
echo "✅ BLUE_IMAGE: $BLUE_IMAGE"

if [ -z "$GREEN_IMAGE" ] || [ "$GREEN_IMAGE" = "your-registry/green-app:latest" ]; then
    echo "❌ GREEN_IMAGE not configured in .env"
    exit 1
fi
echo "✅ GREEN_IMAGE: $GREEN_IMAGE"

if [ -z "$ACTIVE_POOL" ]; then
    echo "❌ ACTIVE_POOL not set in .env"
    exit 1
fi
echo "✅ ACTIVE_POOL: $ACTIVE_POOL"

echo "✅ RELEASE_ID_BLUE: ${RELEASE_ID_BLUE:-not set}"
echo "✅ RELEASE_ID_GREEN: ${RELEASE_ID_GREEN:-not set}"
echo "✅ PORT: ${PORT:-3000}"

# Make scripts executable
echo ""
echo "Making scripts executable..."
chmod +x entrypoint.sh test-failover.sh 2>/dev/null || true
echo "✅ Scripts are executable"

# Validate Docker Compose file
echo ""
echo "Validating docker-compose.yml..."
if docker-compose config > /dev/null 2>&1; then
    echo "✅ docker-compose.yml is valid"
else
    echo "❌ docker-compose.yml validation failed"
    exit 1
fi

# Pull images
echo ""
read -p "Do you want to pull the images now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Pulling images..."
    docker-compose pull || echo "⚠️  Image pull failed. Images may not exist yet."
fi

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "  1. Start services:    docker-compose up -d"
echo "  2. Check status:      docker-compose ps"
echo "  3. View logs:         docker-compose logs -f"
echo "  4. Run tests:         ./test-failover.sh"
echo "  5. Or use Makefile:   make up && make test"
echo ""
echo "Endpoints:"
echo "  - Nginx proxy:        http://localhost:8080"
echo "  - Blue direct:        http://localhost:8081"
echo "  - Green direct:       http://localhost:8082"
echo ""