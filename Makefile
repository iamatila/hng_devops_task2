.PHONY: help up down restart logs test test-blue test-green chaos-start chaos-stop switch-green switch-blue clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

up: ## Start all services
	@echo "Starting services..."
	chmod +x entrypoint.sh test-failover.sh
	docker-compose up -d
	@echo "Waiting for services to be ready..."
	@sleep 5
	@echo "Services started!"
	@make status

down: ## Stop all services
	@echo "Stopping services..."
	docker-compose down

restart: ## Restart all services
	@make down
	@make up

logs: ## Show logs from all services
	docker-compose logs -f

logs-nginx: ## Show Nginx logs
	docker-compose logs -f nginx

logs-blue: ## Show Blue app logs
	docker-compose logs -f app_blue

logs-green: ## Show Green app logs
	docker-compose logs -f app_green

status: ## Check service status
	@echo "\n=== Service Status ==="
	@docker-compose ps
	@echo "\n=== Testing Nginx endpoint ==="
	@curl -s -I http://localhost:8080/version | grep -E "(HTTP|X-App-Pool|X-Release-Id)" || true
	@echo ""

test: ## Run full failover test
	@./test-failover.sh

test-blue: ## Test Blue service directly
	@echo "Testing Blue service (localhost:8081)..."
	@curl -s http://localhost:8081/version | jq .
	@curl -s -I http://localhost:8081/version | grep -E "X-App-Pool|X-Release-Id"

test-green: ## Test Green service directly
	@echo "Testing Green service (localhost:8082)..."
	@curl -s http://localhost:8082/version | jq .
	@curl -s -I http://localhost:8082/version | grep -E "X-App-Pool|X-Release-Id"

test-proxy: ## Test through Nginx proxy
	@echo "Testing through Nginx (localhost:8080)..."
	@for i in 1 2 3 4 5; do \
		echo "Request $$i:"; \
		curl -s -I http://localhost:8080/version | grep -E "(HTTP|X-App-Pool|X-Release-Id)"; \
		echo ""; \
		sleep 1; \
	done

chaos-start: ## Start chaos on Blue (error mode)
	@echo "Starting chaos on Blue..."
	@curl -s -X POST http://localhost:8081/chaos/start?mode=error
	@echo "\nChaos started! Blue should now return errors."
	@echo "Test with: make test-proxy"

chaos-stop: ## Stop chaos on Blue
	@echo "Stopping chaos on Blue..."
	@curl -s -X POST http://localhost:8081/chaos/stop
	@echo "\nChaos stopped! Blue should now work normally."
	@sleep 6
	@echo "Waiting 6s for Blue to recover..."

switch-green: ## Switch to Green as primary
	@echo "Switching to Green as primary..."
	@sed -i.bak 's/ACTIVE_POOL=.*/ACTIVE_POOL=green/' .env
	@docker-compose up -d --force-recreate nginx
	@echo "Switched to Green!"
	@make status

switch-blue: ## Switch to Blue as primary
	@echo "Switching to Blue as primary..."
	@sed -i.bak 's/ACTIVE_POOL=.*/ACTIVE_POOL=blue/' .env
	@docker-compose up -d --force-recreate nginx
	@echo "Switched to Blue!"
	@make status

clean: ## Stop services and remove volumes
	@echo "Cleaning up..."
	docker-compose down -v
	rm -f .env.bak
	@echo "Cleanup complete!"

validate: ## Validate configuration files
	@echo "Validating Docker Compose configuration..."
	@docker-compose config > /dev/null && echo "✅ docker-compose.yml is valid"
	@echo "\nValidating .env file..."
	@test -f .env && echo "✅ .env file exists" || (echo "❌ .env file missing" && exit 1)
	@grep -q "BLUE_IMAGE" .env && echo "✅ BLUE_IMAGE is set" || (echo "❌ BLUE_IMAGE not set" && exit 1)
	@grep -q "GREEN_IMAGE" .env && echo "✅ GREEN_IMAGE is set" || (echo "❌ GREEN_IMAGE not set" && exit 1)

quick-test: up ## Quick test: start and verify basic functionality
	@echo "\n=== Quick Functionality Test ==="
	@sleep 8
	@echo "Testing Nginx endpoint..."
	@curl -s http://localhost:8080/version | jq . || echo "JSON parsing failed, but service might be working"
	@echo "\nChecking headers..."
	@curl -s -I http://localhost:8080/version | grep -E "X-App-Pool|X-Release-Id"
	@echo "\n✅ Basic functionality verified!"