# OBS Remote Control System

## Overview

The OBS Remote Control system allows streamers to control their OBS Studio instance directly from Discord using sophisticated bot commands. This advanced feature demonstrates:

- **WebSocket Communication** - Real-time bidirectional communication with OBS
- **Connection Pooling** - Efficient management of multiple user connections
- **Async/Await Patterns** - Modern Python async programming
- **State Management** - Connection tracking with Redis caching
- **Error Handling** - Robust error handling and reconnection logic
- **API Persistence** - Rails backend for connection data

## Architecture

### Components

1. **`utils/obs_client.py`** - Core WebSocket client
   - Implements obs-websocket protocol v5.x
   - Connection pooling and management
   - Authentication with challenge-response
   - Request/response tracking
   - Event handling and subscriptions
   - Automatic reconnection with exponential backoff

2. **`cogs/obs.py`** - Discord command interface
   - 30+ commands for OBS control
   - Scene management
   - Source control
   - Stream/recording control
   - Filter management
   - Advanced features (screenshots, media control, hotkeys)

3. **Rails API** (`app/controllers/api/v1/obs_connections_controller.rb`)
   - Persistent connection storage
   - Connection history tracking
   - Statistics and analytics

4. **ActiveRecord Model** (`app/models/obs_connection.rb`)
   - Connection data model
   - Uptime calculations
   - Status tracking

## Setup Instructions

### 1. Enable OBS WebSocket Server

In OBS Studio:
1. Go to **Tools → WebSocket Server Settings**
2. Enable **WebSocket server**
3. Set port (default: 4455)
4. Set password (optional but recommended)
5. Click **Apply**

### 2. Bot Configuration

No additional environment variables needed - connections are managed per-user.

### 3. Install Dependencies

```bash
cd discord_bot
pip install -r requirements.txt
```

Dependencies already included:
- `aiohttp==3.9.1` - WebSocket client
- `discord.py==2.3.2` - Discord bot framework

### 4. Run the Bot

```bash
python bot.py
```

## Command Reference

### Connection Management

#### `!obs connect [host] [port] [password]`
Connect to your OBS instance.

**Examples:**
```
!obs connect
!obs connect localhost 4455
!obs connect 192.168.1.100 4455 mypassword
```

**What it does:**
- Establishes WebSocket connection to OBS
- Authenticates using SHA256 challenge-response
- Stores connection in pool
- Persists to database
- Returns OBS version information

#### `!obs disconnect`
Disconnect from OBS.

#### `!obs status`
Check connection status and OBS statistics.

**Returns:**
- Connection status
- Stream status (live/offline, duration)
- Recording status
- Performance metrics (FPS, CPU, memory)
- Stream stats (bitrate, dropped frames)

### Scene Management

#### `!obs scenes`
List all scenes in OBS with current scene highlighted.

#### `!obs scene <scene name>`
Switch to a different scene.

**Example:**
```
!obs scene Main Camera
!obs scene Gaming
```

#### `!obs preview <scene name>`
Set preview scene (Studio Mode only).

#### `!obs transition`
Trigger studio mode transition from preview to program.

### Source Control

#### `!obs sources [scene name]`
List all sources in a scene (defaults to current scene).

#### `!obs show <source name>`
Show (enable) a source.

**Example:**
```
!obs show Webcam
!obs show "Donation Goal"
```

#### `!obs hide <source name>`
Hide (disable) a source.

### Stream Control

#### `!obs startstream`
Start streaming to configured service.

#### `!obs stopstream`
Stop streaming.

#### `!obs startrecord`
Start local recording.

#### `!obs stoprecord`
Stop recording and get file path.

### Text and Browser Sources

#### `!obs settext <source name> <text>`
Update text in a text source.

**Example:**
```
!obs settext "Follower Count" Now at 500 followers!
!obs settext "Latest Donation" Thanks to @user for $50!
```

**Use cases:**
- Update donation goals
- Display chat messages
- Show game stats
- Countdown timers

#### `!obs refreshbrowser <source name>`
Refresh a browser source (useful for testing alerts).

**Example:**
```
!obs refreshbrowser Alerts
!obs refreshbrowser "StreamElements Overlay"
```

### Filter Management

#### `!obs filters <source name>`
List all filters on a source.

#### `!obs togglefilter <source name> <filter name>`
Toggle a filter on/off.

**Example:**
```
!obs togglefilter Webcam "Color Correction"
!obs togglefilter Microphone "Noise Suppression"
```

**Use cases:**
- Toggle chroma key
- Enable/disable color correction
- Switch between audio filters
- Apply effects on demand

### Advanced Features

#### `!obs screenshot [format]`
Take a screenshot of current OBS output.

**Formats:** png, jpg, jpeg

#### `!obs media <action> <source name>`
Control media source playback.

**Actions:** play, pause, restart, stop, next, previous

**Example:**
```
!obs media play "Background Music"
!obs media next "Playlist"
!obs media restart "Intro Video"
```

#### `!obs hotkey <hotkey name>`
Trigger an OBS hotkey by name.

**Example:**
```
!obs hotkey OBS_KEY_F13
!obs hotkey StreamDeck.Toggle
```

## Technical Deep Dive

### WebSocket Protocol

The OBS WebSocket protocol uses JSON messages with operation codes (OpCodes):

- **OpCode 0 (Hello)** - Initial server greeting with auth challenge
- **OpCode 1 (Identify)** - Client authentication
- **OpCode 2 (Identified)** - Authentication success
- **OpCode 5 (Event)** - Server event broadcast
- **OpCode 6 (Request)** - Client request
- **OpCode 7 (RequestResponse)** - Server response
- **OpCode 8 (RequestBatch)** - Multiple requests at once
- **OpCode 9 (RequestBatchResponse)** - Batch response

### Authentication Flow

```python
# 1. Receive Hello with challenge and salt
hello = {
    'op': 0,
    'd': {
        'authentication': {
            'challenge': 'abc123...',
            'salt': 'xyz789...'
        }
    }
}

# 2. Hash password with salt
secret = base64(SHA256(password + salt))

# 3. Hash secret with challenge
auth = base64(SHA256(secret + challenge))

# 4. Send Identify with auth string
identify = {
    'op': 1,
    'd': {
        'authentication': auth,
        'rpcVersion': 1
    }
}
```

### Connection Pooling

The `OBSConnectionPool` manages multiple connections efficiently:

```python
# Get or create connection
client = await obs_pool.get_connection(
    user_id=str(ctx.author.id),
    host='localhost',
    port=4455,
    password='secret'
)

# Reuses existing connections
# Handles reconnection automatically
# Cleans up stale connections
```

### Request/Response Matching

Each request gets a unique ID for matching with responses:

```python
request_id = self.request_id + 1

request_msg = {
    'op': 6,
    'd': {
        'requestType': 'GetSceneList',
        'requestId': str(request_id)
    }
}

# Create future for async response
future = asyncio.Future()
self.pending_requests[request_id] = future

# Wait for response
response = await asyncio.wait_for(future, timeout=10)
```

### Event Handling

Register custom event handlers:

```python
@obs_client.on_event("StreamStateChanged")
async def handle_stream_state(data):
    if data['outputActive']:
        print("Stream started!")
    else:
        print("Stream ended!")

@obs_client.on_event("SceneItemEnableStateChanged")
async def handle_source_visibility(data):
    print(f"Source {data['sceneItemId']} visibility changed")
```

### Error Handling

Comprehensive error handling at multiple levels:

```python
try:
    await client.request("SetCurrentProgramScene", {
        'sceneName': scene_name
    })
except asyncio.TimeoutError:
    # Request timeout
    await ctx.send("Request timed out")
except OBSConnectionError:
    # Connection lost
    await ctx.send("Lost connection to OBS")
except Exception as e:
    # Other errors
    await ctx.send(f"Error: {e}")
```

## Use Cases

### 1. Automated Stream Setup

```python
# Switch to starting soon scene
!obs scene "Starting Soon"

# Show countdown timer
!obs show "Countdown"

# Update text
!obs settext "Stream Title" "Today's Game: Elden Ring"

# Wait for viewers to join...

# Start stream
!obs startstream

# Transition to main scene
!obs scene "Gaming Setup"
```

### 2. Mid-Stream Source Control

```python
# Hide webcam during bathroom break
!obs hide Webcam
!obs scene "BRB Screen"

# Return from break
!obs scene "Main Camera"
!obs show Webcam
```

### 3. Alert Testing

```python
# Refresh alert browser source
!obs refreshbrowser Alerts

# Test notification display
!obs settext "Latest Follower" "Test User"
```

### 4. Recording Management

```python
# Start recording highlight
!obs startrecord

# Play for a while...

# Stop recording
!obs stoprecord
# Returns: Recording saved to: /path/to/video.mp4
```

### 5. Filter Toggling

```python
# Toggle green screen
!obs togglefilter Webcam "Chroma Key"

# Toggle noise gate
!obs togglefilter Microphone "Noise Gate"
```

## Performance Optimizations

### 1. Connection Pooling
Reuses connections instead of creating new ones for each command.

### 2. Request Batching
Execute multiple commands simultaneously:

```python
# Instead of 3 sequential requests:
await client.request("SetCurrentProgramScene", {...})
await client.request("SetSceneItemEnabled", {...})
await client.request("SetSceneItemEnabled", {...})

# Use batch request (coming soon):
await client.batch_request([
    {'requestType': 'SetCurrentProgramScene', ...},
    {'requestType': 'SetSceneItemEnabled', ...},
    {'requestType': 'SetSceneItemEnabled', ...}
])
```

### 3. Redis Caching
Connection state cached in Redis to reduce database queries.

### 4. Async Operations
All I/O operations are non-blocking using async/await.

## Security Considerations

1. **Password Storage**
   - Passwords stored encrypted in database
   - Never logged or displayed
   - Only transmitted over WebSocket

2. **Connection Isolation**
   - Each user has their own connection
   - No cross-user command execution
   - Connection keys scoped by user ID

3. **API Authentication**
   - Rails API requires API key
   - Discord bot token kept secure
   - No public endpoints

4. **Rate Limiting**
   - Discord rate limits apply
   - OBS requests throttled
   - Cooldowns on expensive commands

## Troubleshooting

### "Connection Failed"
**Causes:**
- OBS not running
- WebSocket server disabled
- Wrong host/port
- Firewall blocking connection

**Solutions:**
- Start OBS Studio
- Enable WebSocket server in OBS
- Verify host and port settings
- Check firewall rules

### "Authentication Failed"
**Causes:**
- Wrong password
- Password encryption mismatch

**Solutions:**
- Verify password in OBS settings
- Try connecting without password
- Check for special characters

### "Request Timeout"
**Causes:**
- OBS busy/frozen
- Network latency
- Invalid request

**Solutions:**
- Restart OBS
- Check network connection
- Verify command syntax

### "Source Not Found"
**Causes:**
- Source name typo
- Source in different scene
- Source was deleted

**Solutions:**
- Use `!obs sources` to list sources
- Check exact spelling (case-sensitive)
- Verify source exists

## Future Enhancements

1. **Stream Deck Integration**
   - Virtual stream deck in Discord
   - Custom button layouts
   - Macro recording

2. **Auto-Switching Rules**
   - Scene switching based on game
   - Automatic source visibility
   - Time-based schedules

3. **Performance Monitoring**
   - Real-time alerts for issues
   - FPS drop notifications
   - Encoding overload warnings

4. **Multi-Instance Support**
   - Control multiple OBS instances
   - Switch between computers
   - Remote studio setup

5. **Collaboration Features**
   - Shared control permissions
   - Multi-user access
   - Role-based commands

## API Reference

### Rails Endpoints

#### `GET /api/v1/users/:user_id/obs_connection`
Get user's OBS connection details.

#### `POST /api/v1/users/:user_id/obs_connection`
Create or update OBS connection.

**Parameters:**
```json
{
  "host": "localhost",
  "port": 4455,
  "version": "30.0.0",
  "connected": true
}
```

#### `PATCH /api/v1/users/:user_id/obs_connection`
Update connection status.

#### `DELETE /api/v1/users/:user_id/obs_connection`
Delete OBS connection.

#### `GET /api/v1/users/:user_id/obs_connection/stats`
Get connection statistics.

**Response:**
```json
{
  "stats": {
    "total_connections": 45,
    "total_uptime_seconds": 12850,
    "average_session_duration": 285,
    "last_connected_at": "2025-10-02T14:30:00Z",
    "currently_connected": true
  }
}
```

## Learning Takeaways

This implementation demonstrates:

1. **WebSocket Programming**
   - Real-time bidirectional communication
   - Protocol implementation
   - Message framing and parsing

2. **Async Python**
   - async/await syntax
   - Concurrent operations
   - Future-based responses

3. **Connection Management**
   - Pooling strategies
   - State tracking
   - Lifecycle management

4. **Error Handling**
   - Graceful degradation
   - Retry logic
   - User-friendly errors

5. **API Design**
   - RESTful endpoints
   - Data persistence
   - Statistics tracking

6. **Discord Bot Architecture**
   - Command groups
   - Cog organization
   - User context management

## Contributing

To add new OBS commands:

1. Add method to `OBSControl` cog
2. Use `@obs.command()` decorator
3. Get client: `await self._get_user_connection(ctx.author.id)`
4. Make request: `await client.request("RequestType", {...})`
5. Send response embed

Example:
```python
@obs.command(name='mycommand')
async def my_command(self, ctx: commands.Context):
    """My custom command"""
    client = await self._get_user_connection(ctx.author.id)
    if not client:
        await ctx.send(embed=create_error_embed("Not Connected", "..."))
        return

    try:
        result = await client.request("OBSRequestType", {
            'param1': 'value1'
        })

        await ctx.send(embed=create_success_embed(
            "Success",
            f"Result: {result}"
        ))
    except Exception as e:
        await ctx.send(embed=create_error_embed("Error", str(e)))
```

## License

© 2025 StreamHub. All rights reserved.
