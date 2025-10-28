# Blue/Green Deployment with Nginx Upstream Auto-Failover

This solution implements a Blue/Green deployment pattern with Nginx using primary/backup upstreams for automatic failover.

## Features

- **Automatic Failover**: When the primary (Blue) service fails, Nginx automatically switches to the backup (Green) service
- **Zero Downtime**: Client requests receive 200 responses even during failover
- **Health-based Routing**: Uses `max_fails` and `fail_timeout` for intelligent failover detection
- **Header Preservation**: All app headers (X-App-Pool, X-Release-Id) are forwarded to clients
- **Flexible Chaos Testing**: Supports both error and timeout chaos modes

## Architecture

```
Client → Nginx (port 8080) → Blue (primary) / Green (backup)
                              ├─ Direct access: 8081
                              └─ Direct access: 8082
```

## Setup

1. **Create a `.env` file** with the following variables:

```bash
BLUE_IMAGE=your-blue-image:tag
GREEN_IMAGE=your-green-image:tag
RELEASE_ID_BLUE=v1.0.0
RELEASE_ID_GREEN=v1.0.1
ACTIVE_POOL=blue
PORT=3000
```

2. **Start the deployment**:

```bash
docker compose up -d
```

3. **Verify services are running**:

```bash
docker compose ps
```

## Testing

Run the comprehensive test suite:

```bash
./test-blue-green.sh
```

The test script validates:
- ✅ All services are healthy
- ✅ Blue is active initially
- ✅ Headers are properly preserved
- ✅ Consecutive requests route to Blue
- ✅ Direct access to both services
- ✅ Chaos-induced failover to Green
- ✅ Zero non-200 responses during chaos
- ✅ Timeout mode chaos handling
- ✅ Recovery after chaos stops
- ✅ Header preservation across requests
- ✅ Rapid request burst handling

## Endpoints

### Public (via Nginx)
- `GET http://localhost:8080/version` - Returns version info with headers

### Blue (Direct)
- `GET http://localhost:8081/healthz` - Health check
- `GET http://localhost:8081/version` - Version info
- `POST http://localhost:8081/chaos/start?mode=error` - Start error chaos
- `POST http://localhost:8081/chaos/start?mode=timeout` - Start timeout chaos
- `POST http://localhost:8081/chaos/stop` - Stop chaos

### Green (Direct)
- `GET http://localhost:8082/healthz` - Health check
- `GET http://localhost:8082/version` - Version info
- `POST http://localhost:8082/chaos/start?mode=error` - Start error chaos
- `POST http://localhost:8082/chaos/start?mode=timeout` - Start timeout chaos
- `POST http://localhost:8082/chaos/stop` - Stop chaos

## How It Works

### Normal Operation
- All traffic goes to Blue (primary upstream)
- Green serves as backup (marked with `backup` directive)
- Responses include `X-App-Pool: blue` and `X-Release-Id` headers

### Failover Process
1. Chaos is induced on Blue (via `/chaos/start` endpoint)
2. Nginx detects failure (`max_fails=1`, `fail_timeout=5s`)
3. Nginx automatically retries to Green (within same request)
4. Client receives 200 response from Green
5. Subsequent requests go directly to Green
6. After `fail_timeout`, Nginx retries Blue
7. If Blue recovers, traffic returns to Blue

### Key Nginx Configuration

```nginx
upstream backend {
    server app_blue:3000 max_fails=1 fail_timeout=5s;  # Primary with aggressive failover
    server app_green:3000 backup;                      # Backup
}
```

- `max_fails=1`: Fail after 1 unsuccessful attempt
- `fail_timeout=5s`: Consider failed for 5 seconds
- `backup`: Only used when primary fails
- Timeouts: 2-3s for quick failure detection

## Stopping the Deployment

```bash
docker compose down
```

## Test Coverage

The test script (`test-blue-green.sh`) provides comprehensive validation:

1. **Service Health**: Verifies all endpoints are reachable
2. **Initial State**: Confirms Blue is active by default
3. **Header Validation**: Ensures X-App-Pool and X-Release-Id headers
4. **Consecutive Requests**: Tests consistent routing to Blue
5. **Direct Access**: Validates both services independently
6. **Failover**: Induces chaos and verifies automatic switch to Green
7. **Zero Non-200**: Ensures no failed requests during chaos
8. **Timeout Mode**: Tests timeout-based chaos handling
9. **Recovery**: Verifies return to Blue after chaos stops
10. **Rapid Burst**: Tests high-frequency request handling
