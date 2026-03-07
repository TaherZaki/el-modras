"""
Text-to-Speech Router - Generates natural Arabic speech
"""

import logging
import base64
from typing import Optional, List

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel

from services.gemini_service import gemini_service

logger = logging.getLogger(__name__)
router = APIRouter()


class TTSRequest(BaseModel):
    text: str
    voice_style: Optional[str] = "friendly_teacher"  # friendly_teacher, excited, calm


class TTSResponse(BaseModel):
    audio_base64: Optional[str] = None
    success: bool
    fallback_to_device: bool = False


@router.post("/speak", response_model=TTSResponse)
async def text_to_speech(
    request: TTSRequest,
    authorization: Optional[str] = Header(None)
):
    """Convert Arabic text to natural speech using Gemini TTS (Orus voice)"""
    try:
        # Use Gemini TTS for consistent Orus voice across the app
        result = await gemini_service.generate_natural_speech(
            text=request.text,
            voice_style=request.voice_style
        )
        
        if result.get("success") and result.get("audio_base64"):
            return TTSResponse(
                audio_base64=result["audio_base64"],
                success=True,
                fallback_to_device=False
            )
        
        # Gemini TTS failed - tell client to retry or use device TTS
        logger.warning(f"Gemini TTS failed for: {request.text[:50]}... error: {result.get('error')}")
        return TTSResponse(
            audio_base64=None,
            success=False,
            fallback_to_device=True
        )
        
    except Exception as e:
        logger.error(f"TTS error: {e}")
        return TTSResponse(
            audio_base64=None,
            success=False,
            fallback_to_device=True
        )
