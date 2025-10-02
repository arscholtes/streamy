"""
OBS WebSocket Client
Advanced WebSocket client for controlling OBS Studio remotely
Implements obs-websocket protocol v5.x with connection pooling and state management
"""
import asyncio
import json
import logging
import hashlib
import base64
from typing import Optional, Dict, Any, List
from datetime import datetime, timedelta
import aiohttp
from utils.redis_client import redis_client

logger = logging.getLogger(__name__)


class OBSConnectionError(Exception):
    """Raised when OBS connection fails"""
    pass


class OBSAuthenticationError(Exception):
    """Raised when OBS authentication fails"""
    pass


class OBSWebSocketClient:
    """
    Advanced OBS WebSocket client with connection pooling and state management

    Features:
    - Automatic reconnection with exponential backoff
    - Connection pooling per user
    - Authentication with challenge-response
    - Request/response matching with message IDs
    - Event subscription and handling
    - Connection state caching in Redis
    """

    def __init__(self, host: str = "localhost", port: int = 4455, password: str = None):
        self.host = host
        self.port = port
        self.password = password
        self.ws: Optional[aiohttp.ClientWebSocketResponse] = None
        self.session: Optional[aiohttp.ClientSession] = None
        self.connected = False
        self.authenticated = False

        # Request/response tracking
        self.request_id = 0
        self.pending_requests: Dict[int, asyncio.Future] = {}

        # Event handlers
        self.event_handlers: Dict[str, List[callable]] = {}

        # Connection state
        self.last_heartbeat = None
        self.reconnect_attempts = 0
        self.max_reconnect_attempts = 5

    @property
    def url(self) -> str:
        """WebSocket URL"""
        return f"ws://{self.host}:{self.port}"

    async def connect(self, timeout: int = 10) -> bool:
        """
        Connect to OBS WebSocket server with authentication

        Args:
            timeout: Connection timeout in seconds

        Returns:
            True if connection successful, False otherwise

        Raises:
            OBSConnectionError: If connection fails
            OBSAuthenticationError: If authentication fails
        """
        try:
            # Create session if needed
            if not self.session:
                self.session = aiohttp.ClientSession()

            # Connect to WebSocket
            logger.info(f"Connecting to OBS at {self.url}")
            self.ws = await asyncio.wait_for(
                self.session.ws_connect(self.url),
                timeout=timeout
            )

            # Wait for Hello message
            hello_msg = await asyncio.wait_for(
                self.ws.receive_json(),
                timeout=timeout
            )

            if hello_msg.get('op') != 0:  # OpCode 0 = Hello
                raise OBSConnectionError("Expected Hello message from OBS")

            # Authenticate if password is set
            auth_required = hello_msg.get('d', {}).get('authentication')
            if auth_required:
                if not self.password:
                    raise OBSAuthenticationError("OBS requires authentication but no password provided")

                await self._authenticate(auth_required)
            else:
                # Send Identify without authentication
                await self._send_identify()

            # Wait for Identified message
            identified_msg = await asyncio.wait_for(
                self.ws.receive_json(),
                timeout=timeout
            )

            if identified_msg.get('op') != 2:  # OpCode 2 = Identified
                raise OBSAuthenticationError("Authentication failed")

            self.connected = True
            self.authenticated = True
            self.reconnect_attempts = 0

            # Start message listener
            asyncio.create_task(self._message_listener())

            # Cache connection state
            self._cache_connection_state(True)

            logger.info("Successfully connected to OBS")
            return True

        except asyncio.TimeoutError:
            raise OBSConnectionError(f"Connection timeout after {timeout}s")
        except Exception as e:
            logger.error(f"OBS connection error: {e}")
            raise OBSConnectionError(f"Failed to connect: {e}")

    async def _authenticate(self, auth_data: Dict[str, Any]):
        """
        Authenticate with OBS using challenge-response

        OBS uses SHA256 hashing for authentication:
        1. Get challenge and salt from Hello message
        2. Hash: base64(SHA256(password + salt))
        3. Hash: base64(SHA256(secret + challenge))
        4. Send authentication string in Identify message
        """
        challenge = auth_data.get('challenge')
        salt = auth_data.get('salt')

        if not challenge or not salt:
            raise OBSAuthenticationError("Invalid authentication data from OBS")

        # Step 1: Hash password with salt
        secret_string = self.password + salt
        secret_hash = hashlib.sha256(secret_string.encode()).digest()
        secret = base64.b64encode(secret_hash).decode()

        # Step 2: Hash secret with challenge
        auth_string = secret + challenge
        auth_hash = hashlib.sha256(auth_string.encode()).digest()
        auth_response = base64.b64encode(auth_hash).decode()

        # Send Identify with authentication
        await self._send_identify(auth_response)

    async def _send_identify(self, authentication: Optional[str] = None):
        """Send Identify message to OBS"""
        identify_msg = {
            'op': 1,  # OpCode 1 = Identify
            'd': {
                'rpcVersion': 1,
                'eventSubscriptions': 33  # Subscribe to all events (bitmask)
            }
        }

        if authentication:
            identify_msg['d']['authentication'] = authentication

        await self.ws.send_json(identify_msg)

    async def _message_listener(self):
        """
        Background task to listen for messages from OBS
        Handles events, responses, and heartbeats
        """
        try:
            async for msg in self.ws:
                if msg.type == aiohttp.WSMsgType.TEXT:
                    data = json.loads(msg.data)
                    op_code = data.get('op')

                    # OpCode 5 = Event
                    if op_code == 5:
                        await self._handle_event(data.get('d', {}))

                    # OpCode 7 = RequestResponse
                    elif op_code == 7:
                        await self._handle_response(data.get('d', {}))

                    # OpCode 9 = RequestBatchResponse
                    elif op_code == 9:
                        await self._handle_batch_response(data.get('d', {}))

                elif msg.type == aiohttp.WSMsgType.ERROR:
                    logger.error(f"WebSocket error: {msg.data}")
                    break

        except Exception as e:
            logger.error(f"Message listener error: {e}")
        finally:
            self.connected = False
            self.authenticated = False
            await self._handle_disconnect()

    async def _handle_event(self, event_data: Dict[str, Any]):
        """Handle incoming events from OBS"""
        event_type = event_data.get('eventType')
        event_payload = event_data.get('eventData', {})

        logger.debug(f"OBS Event: {event_type}")

        # Update last heartbeat for certain events
        self.last_heartbeat = datetime.utcnow()

        # Call registered event handlers
        if event_type in self.event_handlers:
            for handler in self.event_handlers[event_type]:
                try:
                    await handler(event_payload)
                except Exception as e:
                    logger.error(f"Event handler error: {e}")

    async def _handle_response(self, response_data: Dict[str, Any]):
        """Handle response to a request"""
        request_id = response_data.get('requestId')

        if request_id in self.pending_requests:
            future = self.pending_requests.pop(request_id)

            if response_data.get('requestStatus', {}).get('result'):
                future.set_result(response_data.get('responseData', {}))
            else:
                error_code = response_data.get('requestStatus', {}).get('code')
                error_comment = response_data.get('requestStatus', {}).get('comment', 'Unknown error')
                future.set_exception(Exception(f"OBS Error {error_code}: {error_comment}"))

    async def _handle_batch_response(self, response_data: Dict[str, Any]):
        """Handle batch response"""
        request_id = response_data.get('requestId')

        if request_id in self.pending_requests:
            future = self.pending_requests.pop(request_id)
            future.set_result(response_data.get('results', []))

    async def _handle_disconnect(self):
        """Handle disconnection and attempt reconnection"""
        logger.warning("OBS WebSocket disconnected")
        self._cache_connection_state(False)

        # Attempt reconnection with exponential backoff
        if self.reconnect_attempts < self.max_reconnect_attempts:
            self.reconnect_attempts += 1
            backoff = min(2 ** self.reconnect_attempts, 60)  # Max 60s

            logger.info(f"Reconnecting in {backoff}s (attempt {self.reconnect_attempts}/{self.max_reconnect_attempts})")
            await asyncio.sleep(backoff)

            try:
                await self.connect()
            except Exception as e:
                logger.error(f"Reconnection failed: {e}")

    async def request(self, request_type: str, request_data: Optional[Dict[str, Any]] = None, timeout: int = 10) -> Dict[str, Any]:
        """
        Send a request to OBS and wait for response

        Args:
            request_type: Type of request (e.g., "GetSceneList")
            request_data: Optional request parameters
            timeout: Request timeout in seconds

        Returns:
            Response data from OBS

        Raises:
            OBSConnectionError: If not connected
            Exception: If request fails
        """
        if not self.connected:
            raise OBSConnectionError("Not connected to OBS")

        # Generate request ID
        self.request_id += 1
        request_id = self.request_id

        # Create request message
        request_msg = {
            'op': 6,  # OpCode 6 = Request
            'd': {
                'requestType': request_type,
                'requestId': str(request_id)
            }
        }

        if request_data:
            request_msg['d']['requestData'] = request_data

        # Create future for response
        future = asyncio.Future()
        self.pending_requests[request_id] = future

        # Send request
        await self.ws.send_json(request_msg)

        # Wait for response
        try:
            response = await asyncio.wait_for(future, timeout=timeout)
            return response
        except asyncio.TimeoutError:
            self.pending_requests.pop(request_id, None)
            raise Exception(f"Request timeout after {timeout}s")

    async def batch_request(self, requests: List[Dict[str, Any]], timeout: int = 10) -> List[Dict[str, Any]]:
        """
        Send multiple requests in a batch for better performance

        Args:
            requests: List of request dicts with 'requestType' and optional 'requestData'
            timeout: Request timeout in seconds

        Returns:
            List of responses
        """
        if not self.connected:
            raise OBSConnectionError("Not connected to OBS")

        # Generate request ID
        self.request_id += 1
        request_id = self.request_id

        # Create batch request message
        batch_msg = {
            'op': 8,  # OpCode 8 = RequestBatch
            'd': {
                'requestId': str(request_id),
                'requests': requests
            }
        }

        # Create future for response
        future = asyncio.Future()
        self.pending_requests[request_id] = future

        # Send batch request
        await self.ws.send_json(batch_msg)

        # Wait for response
        try:
            responses = await asyncio.wait_for(future, timeout=timeout)
            return responses
        except asyncio.TimeoutError:
            self.pending_requests.pop(request_id, None)
            raise Exception(f"Batch request timeout after {timeout}s")

    def on_event(self, event_type: str):
        """
        Decorator to register event handlers

        Example:
            @obs_client.on_event("StreamStateChanged")
            async def handle_stream_state(data):
                print(f"Stream state: {data['outputActive']}")
        """
        def decorator(func):
            if event_type not in self.event_handlers:
                self.event_handlers[event_type] = []
            self.event_handlers[event_type].append(func)
            return func
        return decorator

    async def disconnect(self):
        """Disconnect from OBS gracefully"""
        if self.ws and not self.ws.closed:
            await self.ws.close()

        if self.session and not self.session.closed:
            await self.session.close()

        self.connected = False
        self.authenticated = False
        self._cache_connection_state(False)

        logger.info("Disconnected from OBS")

    def _cache_connection_state(self, connected: bool):
        """Cache connection state in Redis"""
        cache_key = f"obs:connection:{self.host}:{self.port}"
        redis_client.set(cache_key, {
            'connected': connected,
            'timestamp': datetime.utcnow().isoformat()
        }, ttl=300)  # 5 minutes

    async def __aenter__(self):
        """Async context manager entry"""
        await self.connect()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        await self.disconnect()


class OBSConnectionPool:
    """
    Connection pool manager for multiple OBS connections
    Allows per-user or per-server OBS connections
    """

    def __init__(self):
        self.connections: Dict[str, OBSWebSocketClient] = {}
        self.lock = asyncio.Lock()

    async def get_connection(self, user_id: str, host: str = "localhost", port: int = 4455, password: str = None) -> OBSWebSocketClient:
        """
        Get or create an OBS connection for a user

        Args:
            user_id: Unique identifier for this connection (e.g., Discord user ID)
            host: OBS host
            port: OBS WebSocket port
            password: OBS WebSocket password

        Returns:
            OBSWebSocketClient instance
        """
        async with self.lock:
            conn_key = f"{user_id}:{host}:{port}"

            # Return existing connection if still active
            if conn_key in self.connections:
                client = self.connections[conn_key]
                if client.connected:
                    return client
                else:
                    # Remove stale connection
                    await client.disconnect()
                    del self.connections[conn_key]

            # Create new connection
            client = OBSWebSocketClient(host, port, password)
            await client.connect()
            self.connections[conn_key] = client

            return client

    async def remove_connection(self, user_id: str, host: str = "localhost", port: int = 4455):
        """Remove and disconnect a connection"""
        async with self.lock:
            conn_key = f"{user_id}:{host}:{port}"

            if conn_key in self.connections:
                client = self.connections[conn_key]
                await client.disconnect()
                del self.connections[conn_key]

    async def close_all(self):
        """Close all connections in the pool"""
        async with self.lock:
            for client in self.connections.values():
                await client.disconnect()
            self.connections.clear()


# Global connection pool
obs_pool = OBSConnectionPool()
