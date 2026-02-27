"""
Chat Router - Handles text-based chat with Gemini (fallback)
"""

import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel

from services.gemini_service import gemini_service

logger = logging.getLogger(__name__)
router = APIRouter()


class ChatRequest(BaseModel):
    text: str
    session_id: Optional[str] = None


class ChatResponse(BaseModel):
    text: str
    arabic_text: Optional[str] = None


class ChatMessageRequest(BaseModel):
    message: str
    context: str
    session_id: Optional[str] = None


class ChatMessageResponse(BaseModel):
    reply: str


@router.post("", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    authorization: Optional[str] = Header(None)
):
    """Send a text message and receive a response"""
    try:
        result = await gemini_service.chat(
            message=request.text,
            session_id=request.session_id
        )
        
        return ChatResponse(
            text=result["text"],
            arabic_text=result.get("arabic_text")
        )
        
    except Exception as e:
        logger.error(f"Failed to process chat: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/message", response_model=ChatMessageResponse)
async def chat_message(
    request: ChatMessageRequest,
    authorization: Optional[str] = Header(None)
):
    """Send a message with context and get a reply (for asking questions to the teacher)"""
    try:
        result = await gemini_service.chat_with_context(
            message=request.message,
            context=request.context,
            session_id=request.session_id
        )
        
        return ChatMessageResponse(reply=result)
        
    except Exception as e:
        logger.error(f"Failed to process chat message: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/translate")
async def translate(
    text: str,
    direction: str = "en_to_ar",  # or "ar_to_en"
    authorization: Optional[str] = Header(None)
):
    """Translate text between English and Arabic"""
    try:
        if direction == "en_to_ar":
            prompt = f"Translate this English text to Arabic. Only respond with the Arabic translation, nothing else: {text}"
        else:
            prompt = f"Translate this Arabic text to English. Only respond with the English translation, nothing else: {text}"
        
        result = await gemini_service.chat(message=prompt)
        
        return {
            "original": text,
            "translated": result["text"],
            "direction": direction
        }
        
    except Exception as e:
        logger.error(f"Failed to translate: {e}")
        raise HTTPException(status_code=500, detail=str(e))
