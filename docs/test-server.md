# Test Server Documentation

The Momentum app includes a built-in HTTP test server for debugging and automated testing (DEBUG builds only).

## Overview

The test server provides HTTP endpoints to control the app and inspect its state without manual UI interaction. It automatically starts on port 8765 when the app launches in DEBUG mode.

## Endpoints

### 1. Execute Momentum Commands
```bash
POST /momentum
Content-Type: application/json

{
  "command": "start",
  "args": ["--goal", "Test goal", "--time", "25"]
}

# Example:
curl -X POST http://localhost:8765/momentum \
  -H "Content-Type: application/json" \
  -d '{"command": "start", "args": ["--goal", "Test goal", "--time", "25"]}'
```

Returns:
```json
{
  "output": "...",
  "error": "...",
  "exitCode": 0
}
```

### 2. Show Menu
Forces the menu popover to appear.

```bash
POST /show

# Example:
curl -X POST http://localhost:8765/show
```

### 3. Refresh State
Forces the app to reload state from disk.

```bash
POST /refresh

# Example:
curl -X POST http://localhost:8765/refresh
```

### 4. Get Logs
Returns application logs captured by the test server.

```bash
GET /logs

# Example:
curl http://localhost:8765/logs
```

### 5. Get Current State
Returns the current TCA state as JSON.

```bash
GET /state

# Example:
curl http://localhost:8765/state
```

Returns:
```json
{
  "hasSession": true,
  "sessionGoal": "Test goal",
  "reflectionPath": "",
  "analysisCount": 0,
  "isLoading": false,
  "destination": "activeSession"
}
```

## Testing Workflows

### Complete Session Flow
```bash
# 1. Start a session
curl -X POST http://localhost:8765/momentum \
  -d '{"command": "start", "args": ["--goal", "Write tests", "--time", "30"]}'

# 2. Check state
curl http://localhost:8765/state

# 3. Stop the session
curl -X POST http://localhost:8765/momentum \
  -d '{"command": "stop", "args": []}'

# 4. Analyze the reflection
curl -X POST http://localhost:8765/momentum \
  -d '{"command": "analyze", "args": ["--file", "/path/to/reflection.md"]}'
```

### Debugging Claude Integration
```bash
# Create a test reflection file first
echo "Test reflection content" > /tmp/test-reflection.md

# Test analyze command
curl -X POST http://localhost:8765/momentum \
  -d '{"command": "analyze", "args": ["--file", "/tmp/test-reflection.md"]}'

# Check logs for any errors
curl http://localhost:8765/logs
```

## Implementation Details

- Server runs on port 8765 by default
- Only available in DEBUG builds
- Uses Apple's Network framework (NWListener)
- Logs are buffered (max 1000 entries)
- All endpoints return plain text or JSON

## Security Note

The test server is intentionally only available in DEBUG builds and should never be enabled in production releases. It provides unrestricted access to the momentum CLI and app state.