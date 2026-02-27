"""
Gemini Live Service - Real-time audio interaction with Gemini
This enables natural conversation with interruption support
"""

import logging
import base64
import asyncio
import json
from typing import Optional, Dict, Any, Callable, AsyncGenerator
from dataclasses import dataclass
from enum import Enum

import google.generativeai as genai

from config import settings

logger = logging.getLogger(__name__)


class LiveSessionState(Enum):
    """States for the live session"""
    IDLE = "idle"
    LISTENING = "listening"
    PROCESSING = "processing"
    SPEAKING = "speaking"
    INTERRUPTED = "interrupted"


@dataclass
class LiveSessionConfig:
    """Configuration for live session"""
    voice_name: str = "Aoede"
    language_code: str = "ar-XA"
    response_modality: str = "AUDIO"
    system_instruction: str = ""
    

class GeminiLiveService:
    """
    Service for Gemini API with real-time-like audio interaction.
    Supports:
    - Audio input/output
    - Interruption handling
    - Natural conversation flow
    """
    
    _instance = None
    _initialized = False
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self):
        if GeminiLiveService._initialized:
            return
        
        self.model = None
        self.active_sessions: Dict[str, Any] = {}
        self.is_initialized = False
        
        # Arabic tutor system instruction for kids
        self.system_instruction = """أنت المُدَرِّس (EL-Modras)، معلم لغة عربية ودود للأطفال.

تعليمات مهمة:
1. تكلم بالعربية الفصحى البسيطة أو العامية المصرية حسب طلب الطالب
2. كن صبوراً ومشجعاً دائماً
3. عند تعليم كلمة جديدة، انطقها ببطء وواضح
4. شجع الطفل عند الإجابة الصحيحة: "برافو! شاطر!"
5. عند الخطأ، صحح بلطف: "قريب! جرب تاني"
6. استخدم جمل قصيرة وبسيطة
7. أضف نغمة مرحة لصوتك

You are EL-Modras, a friendly Arabic teacher for children.
Speak Arabic clearly and slowly. Be encouraging and patient.
Use simple Egyptian dialect when appropriate for kids."""
        
        GeminiLiveService._initialized = True
    
    async def initialize(self):
        """Initialize the Gemini client"""
        if self.is_initialized:
            return
        
        try:
            genai.configure(api_key=settings.gemini_api_key)
            self.model = genai.GenerativeModel(
                model_name="gemini-2.5-flash",
                system_instruction=self.system_instruction
            )
            self.is_initialized = True
            logger.info("Gemini Live Service initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Gemini Live Service: {e}")
            raise
    
    async def ensure_initialized(self):
        """Ensure client is initialized"""
        if not self.is_initialized:
            await self.initialize()
    
    async def create_live_session(
        self,
        session_id: str,
        lesson_context: Optional[str] = None,
        on_audio_response: Optional[Callable[[bytes], None]] = None,
        on_text_response: Optional[Callable[[str], None]] = None,
        on_interrupted: Optional[Callable[[], None]] = None
    ) -> Dict[str, Any]:
        """
        Create a new live session for real-time audio conversation.
        """
        try:
            await self.ensure_initialized()
            
            # Build system instruction with lesson context
            full_instruction = self.system_instruction
            if lesson_context:
                full_instruction += f"\n\nCurrent lesson: {lesson_context}"
            
            # Create a chat session
            chat = self.model.start_chat(history=[])
            
            # Store session info
            self.active_sessions[session_id] = {
                "chat": chat,
                "state": LiveSessionState.IDLE,
                "lesson_context": lesson_context,
                "on_audio_response": on_audio_response,
                "on_text_response": on_text_response,
                "on_interrupted": on_interrupted,
                "is_interrupted": False,
                "conversation_history": []
            }
            
            logger.info(f"Live session created: {session_id}")
            
            return {
                "session_id": session_id,
                "status": "created",
                "supports_interruption": True,
                "model": "gemini-2.5-flash"
            }
            
        except Exception as e:
            logger.error(f"Failed to create live session: {e}")
            raise
    
    async def send_audio_and_get_response(
        self, 
        session_id: str, 
        audio_data: bytes,
        mime_type: str = "audio/wav"
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """
        Send audio and get streaming response.
        This simulates live interaction with streaming responses.
        """
        if session_id not in self.active_sessions:
            yield {"type": "error", "message": "Session not found"}
            return
        
        session = self.active_sessions[session_id]
        session["state"] = LiveSessionState.PROCESSING
        session["is_interrupted"] = False
        
        try:
            # Create multimodal content with audio
            audio_part = {
                "mime_type": mime_type,
                "data": base64.b64encode(audio_data).decode()
            }
            
            prompt = "Listen to this audio and respond appropriately as an Arabic teacher. If the child is practicing pronunciation, give encouraging feedback."
            
            # Use streaming for real-time feel
            response = await asyncio.to_thread(
                session["chat"].send_message,
                [prompt, audio_part],
                stream=True
            )
            
            session["state"] = LiveSessionState.SPEAKING
            
            full_response = ""
            for chunk in response:
                # Check if interrupted
                if session.get("is_interrupted"):
                    yield {"type": "interrupted", "message": "Response interrupted"}
                    break
                
                if chunk.text:
                    full_response += chunk.text
                    yield {
                        "type": "text_chunk",
                        "content": chunk.text
                    }
            
            if not session.get("is_interrupted"):
                yield {
                    "type": "complete",
                    "content": full_response
                }
            
            session["state"] = LiveSessionState.IDLE
            
        except Exception as e:
            logger.error(f"Error processing audio: {e}")
            yield {"type": "error", "message": str(e)}
            session["state"] = LiveSessionState.IDLE
    
    async def send_text_and_get_response(
        self,
        session_id: str,
        text: str
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """Send text and get streaming response"""
        if session_id not in self.active_sessions:
            yield {"type": "error", "message": "Session not found"}
            return
        
        session = self.active_sessions[session_id]
        session["state"] = LiveSessionState.PROCESSING
        session["is_interrupted"] = False
        
        try:
            response = await asyncio.to_thread(
                session["chat"].send_message,
                text,
                stream=True
            )
            
            session["state"] = LiveSessionState.SPEAKING
            
            full_response = ""
            for chunk in response:
                if session.get("is_interrupted"):
                    yield {"type": "interrupted", "message": "Response interrupted"}
                    break
                
                if chunk.text:
                    full_response += chunk.text
                    yield {
                        "type": "text_chunk",
                        "content": chunk.text
                    }
            
            if not session.get("is_interrupted"):
                yield {
                    "type": "complete",
                    "content": full_response
                }
            
            session["state"] = LiveSessionState.IDLE
            
        except Exception as e:
            logger.error(f"Error sending text: {e}")
            yield {"type": "error", "message": str(e)}
            session["state"] = LiveSessionState.IDLE
    
    async def interrupt(self, session_id: str) -> bool:
        """
        Interrupt the current response (barge-in).
        """
        if session_id not in self.active_sessions:
            return False
        
        session = self.active_sessions[session_id]
        
        if session["state"] in [LiveSessionState.SPEAKING, LiveSessionState.PROCESSING]:
            session["is_interrupted"] = True
            session["state"] = LiveSessionState.INTERRUPTED
            
            if session.get("on_interrupted"):
                session["on_interrupted"]()
            
            logger.info(f"Session interrupted: {session_id}")
            return True
        
        return False
    
    async def end_session(self, session_id: str) -> bool:
        """End a live session"""
        if session_id not in self.active_sessions:
            return False
        
        try:
            del self.active_sessions[session_id]
            logger.info(f"Live session ended: {session_id}")
            return True
        except Exception as e:
            logger.error(f"Error ending session: {e}")
            return False
    
    def get_session_state(self, session_id: str) -> Optional[LiveSessionState]:
        """Get the current state of a session"""
        if session_id not in self.active_sessions:
            return None
        return self.active_sessions[session_id]["state"]
    
    async def cleanup(self):
        """Cleanup all sessions"""
        for session_id in list(self.active_sessions.keys()):
            await self.end_session(session_id)
        self.is_initialized = False
        logger.info("Gemini Live Service cleaned up")


# Singleton instance
gemini_live_service = GeminiLiveService()
