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
    """Convert Arabic text to natural speech using Gemini or Google Cloud TTS"""
    try:
        # Try Gemini's natural speech first
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
        
        # Fallback to Google Cloud TTS
        try:
            from google.cloud import texttospeech
            
            client = texttospeech.TextToSpeechClient()
            
            synthesis_input = texttospeech.SynthesisInput(text=request.text)
            
            # Use WaveNet for natural voice
            voice = texttospeech.VoiceSelectionParams(
                language_code="ar-XA",
                name="ar-XA-Wavenet-B",  # Male Arabic WaveNet voice
                ssml_gender=texttospeech.SsmlVoiceGender.MALE
            )
            
            audio_config = texttospeech.AudioConfig(
                audio_encoding=texttospeech.AudioEncoding.MP3,
                speaking_rate=0.85,  # Slightly slower for kids
                pitch=0.0,
                effects_profile_id=["small-bluetooth-speaker-class-device"]
            )
            
            response = client.synthesize_speech(
                input=synthesis_input,
                voice=voice,
                audio_config=audio_config
            )
            
            audio_base64 = base64.b64encode(response.audio_content).decode('utf-8')
            
            return TTSResponse(
                audio_base64=audio_base64,
                success=True,
                fallback_to_device=False
            )
            
        except Exception as tts_error:
            logger.warning(f"Google Cloud TTS failed: {tts_error}")
            # Tell client to use device TTS
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
