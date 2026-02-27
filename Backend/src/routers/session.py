"""
Session Router - Handles Gemini Live API session management
"""

import uuid
import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, UploadFile, File, Header
from pydantic import BaseModel

from services.gemini_service import gemini_service

logger = logging.getLogger(__name__)
router = APIRouter()


class SessionStartRequest(BaseModel):
    lesson_id: Optional[str] = None
    lesson_context: Optional[str] = None


class SessionStartResponse(BaseModel):
    session_id: str
    status: str
    expires_at: Optional[str] = None


class AudioResponse(BaseModel):
    text: str
    arabic_text: Optional[str] = None
    audio_base64: Optional[str] = None
    audio_url: Optional[str] = None


@router.post("/start", response_model=SessionStartResponse)
async def start_session(
    request: SessionStartRequest = SessionStartRequest(),
    authorization: Optional[str] = Header(None)
):
    """Start a new Gemini Live API session"""
    try:
        session_id = str(uuid.uuid4())
        
        result = await gemini_service.start_live_session(
            session_id=session_id,
            lesson_context=request.lesson_context
        )
        
        return SessionStartResponse(
            session_id=session_id,
            status="active"
        )
        
    except Exception as e:
        logger.error(f"Failed to start session: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{session_id}/audio", response_model=AudioResponse)
async def send_audio(
    session_id: str,
    audio: UploadFile = File(...),
    authorization: Optional[str] = Header(None)
):
    """Send audio message to Gemini and receive response"""
    try:
        # Read audio data
        audio_data = await audio.read()
        
        # Process with Gemini
        result = await gemini_service.send_audio_message(session_id, audio_data)
        
        return AudioResponse(
            text=result["text"],
            arabic_text=result.get("arabic_text"),
            audio_base64=result.get("audio_base64"),
            audio_url=result.get("audio_url")
        )
        
    except Exception as e:
        logger.error(f"Failed to process audio: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/audio-with-context", response_model=AudioResponse)
async def send_audio_with_context(
    audio: UploadFile = File(...),
    context: str = "",
    authorization: Optional[str] = Header(None)
):
    """Send audio message with lesson context to Gemini and receive a contextual response"""
    try:
        # Read audio data
        audio_data = await audio.read()
        
        # Process with Gemini including context
        result = await gemini_service.send_audio_with_context(audio_data, context)
        
        return AudioResponse(
            text=result["text"],
            arabic_text=result.get("arabic_text"),
            audio_base64=result.get("audio_base64"),
            audio_url=result.get("audio_url")
        )
        
    except Exception as e:
        logger.error(f"Failed to process audio with context: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{session_id}/end")
async def end_session(
    session_id: str,
    authorization: Optional[str] = Header(None)
):
    """End a Gemini Live API session"""
    try:
        success = await gemini_service.end_session(session_id)
        
        if success:
            return {"status": "ended", "session_id": session_id}
        else:
            raise HTTPException(status_code=404, detail="Session not found")
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to end session: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{session_id}/status")
async def get_session_status(
    session_id: str,
    authorization: Optional[str] = Header(None)
):
    """Get the status of a session"""
    if session_id in gemini_service.active_sessions:
        session_data = gemini_service.active_sessions[session_id]
        return {
            "session_id": session_id,
            "status": "active",
            "message_count": session_data.get("message_count", 0)
        }
    else:
        return {
            "session_id": session_id,
            "status": "not_found"
        }


@router.post("/{session_id}/interrupt")
async def interrupt_session(
    session_id: str,
    authorization: Optional[str] = Header(None)
):
    """Interrupt the current AI response (barge-in)"""
    try:
        success = await gemini_service.interrupt_session(session_id)
        
        if success:
            return {
                "status": "interrupted",
                "session_id": session_id,
                "message": "Teacher response interrupted"
            }
        else:
            return {
                "status": "not_speaking",
                "session_id": session_id,
                "message": "No response to interrupt"
            }
            
    except Exception as e:
        logger.error(f"Failed to interrupt session: {e}")
        raise HTTPException(status_code=500, detail=str(e))
