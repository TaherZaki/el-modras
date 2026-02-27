"""
Pronunciation Router - Handles pronunciation analysis with Gemini
"""

import logging
from typing import Optional, List

from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Header
from pydantic import BaseModel

from services.gemini_service import gemini_service

logger = logging.getLogger(__name__)
router = APIRouter()


class PronunciationRequest(BaseModel):
    audio_base64: str
    expected_text: str


class PronunciationResponse(BaseModel):
    score: float
    feedback: str
    suggestions: List[str]


@router.post("/analyze", response_model=PronunciationResponse)
async def analyze_pronunciation(
    audio: UploadFile = File(...),
    expected_text: str = Form(...),
    authorization: Optional[str] = Header(None)
):
    """Analyze Arabic pronunciation and provide feedback"""
    try:
        # Read audio data
        audio_data = await audio.read()
        
        # Validate file size (max 10MB)
        if len(audio_data) > 10 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="Audio too large (max 10MB)")
        
        # Analyze with Gemini
        result = await gemini_service.analyze_pronunciation(audio_data, expected_text)
        
        return PronunciationResponse(
            score=result["score"],
            feedback=result["feedback"],
            suggestions=result["suggestions"]
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to analyze pronunciation: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/analyze-json", response_model=PronunciationResponse)
async def analyze_pronunciation_json(
    request: PronunciationRequest,
    authorization: Optional[str] = Header(None)
):
    """Analyze Arabic pronunciation from base64 audio"""
    try:
        import base64
        
        # Decode base64 audio
        audio_data = base64.b64decode(request.audio_base64)
        
        # Analyze with Gemini
        result = await gemini_service.analyze_pronunciation(audio_data, request.expected_text)
        
        return PronunciationResponse(
            score=result["score"],
            feedback=result["feedback"],
            suggestions=result["suggestions"]
        )
        
    except Exception as e:
        logger.error(f"Failed to analyze pronunciation: {e}")
        raise HTTPException(status_code=500, detail=str(e))
