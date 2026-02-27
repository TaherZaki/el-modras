"""
WebSocket Router for Real-time Live API Communication
Enables bidirectional audio streaming with interruption support
"""

import logging
import base64
import json
import asyncio
from typing import Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel

from services.gemini_live_service import gemini_live_service, LiveSessionState

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/live", tags=["live"])


class LiveSessionRequest(BaseModel):
    lesson_context: Optional[str] = None
    language: str = "ar"  # ar for Arabic, en for English


class LiveSessionResponse(BaseModel):
    session_id: str
    status: str
    supports_interruption: bool
    websocket_url: str


@router.post("/session/create")
async def create_live_session(request: LiveSessionRequest) -> LiveSessionResponse:
    """
    Create a new live session for real-time audio conversation.
    Returns session_id and WebSocket URL for streaming.
    """
    import uuid
    session_id = str(uuid.uuid4())
    
    try:
        result = await gemini_live_service.create_live_session(
            session_id=session_id,
            lesson_context=request.lesson_context
        )
        
        return LiveSessionResponse(
            session_id=result["session_id"],
            status=result["status"],
            supports_interruption=result["supports_interruption"],
            websocket_url=f"/api/v1/live/stream/{session_id}"
        )
    except Exception as e:
        logger.error(f"Failed to create live session: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.websocket("/stream/{session_id}")
async def live_audio_stream(websocket: WebSocket, session_id: str):
    """
    WebSocket endpoint for bidirectional audio streaming.
    
    Client sends:
    - {"type": "audio", "data": "<base64_audio>", "mime_type": "audio/wav"}
    - {"type": "text", "content": "<text_message>"}
    - {"type": "interrupt"}
    - {"type": "end"}
    
    Server sends:
    - {"type": "connected", "message": "..."}
    - {"type": "text_chunk", "content": "<text>"}
    - {"type": "complete", "content": "<full_text>"}
    - {"type": "interrupted", "message": "..."}
    - {"type": "error", "message": "..."}
    """
    await websocket.accept()
    logger.info(f"WebSocket connected: {session_id}")
    
    try:
        # Send connected message
        await websocket.send_json({
            "type": "connected",
            "message": "Live session started. Ready to listen."
        })
        
        # Handle incoming messages from client
        while True:
            try:
                data = await websocket.receive_json()
                message_type = data.get("type")
                
                if message_type == "audio":
                    # Client is sending audio
                    audio_base64 = data.get("data", "")
                    mime_type = data.get("mime_type", "audio/wav")
                    
                    if audio_base64:
                        audio_bytes = base64.b64decode(audio_base64)
                        
                        # Process audio and stream response
                        async for response in gemini_live_service.send_audio_and_get_response(
                            session_id, 
                            audio_bytes,
                            mime_type
                        ):
                            await websocket.send_json(response)
                            
                            # Check for interruption
                            if response.get("type") == "interrupted":
                                break
                
                elif message_type == "text":
                    # Client is sending text
                    text = data.get("content", "")
                    if text:
                        # Process text and stream response
                        async for response in gemini_live_service.send_text_and_get_response(
                            session_id, 
                            text
                        ):
                            await websocket.send_json(response)
                            
                            if response.get("type") == "interrupted":
                                break
                
                elif message_type == "interrupt":
                    # Client wants to interrupt
                    success = await gemini_live_service.interrupt(session_id)
                    await websocket.send_json({
                        "type": "interrupted",
                        "message": "Interruption requested",
                        "success": success
                    })
                
                elif message_type == "end":
                    # Client wants to end session
                    logger.info(f"Client requested end of session: {session_id}")
                    break
                    
            except WebSocketDisconnect:
                logger.info(f"WebSocket disconnected: {session_id}")
                break
            except json.JSONDecodeError:
                await websocket.send_json({
                    "type": "error",
                    "message": "Invalid JSON"
                })
            except Exception as e:
                logger.error(f"Error processing message: {e}")
                await websocket.send_json({
                    "type": "error",
                    "message": str(e)
                })
                
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        try:
            await websocket.send_json({"type": "error", "message": str(e)})
        except:
            pass
    finally:
        await gemini_live_service.end_session(session_id)
        logger.info(f"WebSocket session ended: {session_id}")


@router.get("/session/{session_id}/state")
async def get_session_state(session_id: str):
    """Get the current state of a live session"""
    state = gemini_live_service.get_session_state(session_id)
    if state is None:
        raise HTTPException(status_code=404, detail="Session not found")
    
    return {
        "session_id": session_id,
        "state": state.value
    }


@router.delete("/session/{session_id}")
async def end_session(session_id: str):
    """End a live session"""
    success = await gemini_live_service.end_session(session_id)
    if not success:
        raise HTTPException(status_code=404, detail="Session not found")
    
    return {"status": "ended", "session_id": session_id}
