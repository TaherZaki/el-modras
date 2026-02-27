"""
WebSocket Manager for handling real-time audio connections
"""

import logging
from typing import Dict, Optional
from fastapi import WebSocket

logger = logging.getLogger(__name__)


class WebSocketManager:
    """Manages WebSocket connections for real-time audio streaming"""
    
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
    
    async def connect(self, websocket: WebSocket, session_id: str):
        """Accept and store a new WebSocket connection"""
        await websocket.accept()
        self.active_connections[session_id] = websocket
        logger.info(f"WebSocket connected: {session_id}")
    
    def disconnect(self, session_id: str):
        """Remove a WebSocket connection"""
        if session_id in self.active_connections:
            del self.active_connections[session_id]
            logger.info(f"WebSocket disconnected: {session_id}")
    
    async def send_audio(self, session_id: str, audio_data: bytes):
        """Send audio data to a specific client"""
        if session_id in self.active_connections:
            websocket = self.active_connections[session_id]
            await websocket.send_bytes(audio_data)
    
    async def send_text(self, session_id: str, message: str):
        """Send text message to a specific client"""
        if session_id in self.active_connections:
            websocket = self.active_connections[session_id]
            await websocket.send_text(message)
    
    async def broadcast_audio(self, audio_data: bytes, exclude: Optional[str] = None):
        """Broadcast audio to all connected clients"""
        for session_id, websocket in self.active_connections.items():
            if session_id != exclude:
                await websocket.send_bytes(audio_data)
    
    def is_connected(self, session_id: str) -> bool:
        """Check if a session is connected"""
        return session_id in self.active_connections
    
    def get_connection_count(self) -> int:
        """Get the number of active connections"""
        return len(self.active_connections)
