"""
Gemini Live Service - Real-time bidirectional audio interaction
Uses the NEW google-genai SDK with client.aio.live.connect() for true Live API
"""

import logging
import base64
import asyncio
import json
from typing import Optional, Dict, Any, Callable, AsyncGenerator
from dataclasses import dataclass
from enum import Enum

from google import genai
from google.genai import types

from config import settings

logger = logging.getLogger(__name__)


class LiveSessionState(Enum):
    """States for the live session"""
    IDLE = "idle"
    LISTENING = "listening"
    PROCESSING = "processing"
    SPEAKING = "speaking"
    INTERRUPTED = "interrupted"


class GeminiLiveService:
    """
    Service for Gemini Live API with REAL real-time bidirectional audio.
    Uses client.aio.live.connect() for persistent streaming connections.
    
    Supports:
    - Real-time bidirectional audio streaming
    - Interruption handling (barge-in)
    - Natural conversation flow with Arabic tutor persona
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
        
        self.client: Optional[genai.Client] = None
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
        """Initialize the Gemini client with new GenAI SDK"""
        if self.is_initialized:
            return
        
        try:
            self.client = genai.Client(
                api_key=settings.gemini_api_key,
                http_options={"api_version": "v1beta"}
            )
            self.is_initialized = True
            logger.info("Gemini Live Service initialized with new GenAI SDK (Live API)")
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
        Create a new live session using Gemini Live API.
        Establishes a persistent bidirectional connection via client.aio.live.connect()
        """
        try:
            await self.ensure_initialized()
            
            # Build system instruction with lesson context
            full_instruction = self.system_instruction
            if lesson_context:
                full_instruction += f"\n\nCurrent lesson: {lesson_context}"
            
            # Configure the Live API session
            live_config = types.LiveConnectConfig(
                response_modalities=["AUDIO", "TEXT"],
                speech_config=types.SpeechConfig(
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(
                            voice_name="Orus"
                        )
                    )
                ),
                system_instruction=types.Content(
                    parts=[types.Part.from_text(full_instruction)]
                )
            )
            
            # Create the REAL Live API connection using client.aio.live.connect()
            live_session = await self.client.aio.live.connect(
                model="gemini-2.0-flash-live-001",
                config=live_config
            )
            
            # Store session info with the live connection
            self.active_sessions[session_id] = {
                "live_session": live_session,
                "state": LiveSessionState.IDLE,
                "lesson_context": lesson_context,
                "on_audio_response": on_audio_response,
                "on_text_response": on_text_response,
                "on_interrupted": on_interrupted,
                "is_interrupted": False,
                "conversation_history": []
            }
            
            logger.info(f"Live session created with real Live API: {session_id}")
            
            return {
                "session_id": session_id,
                "status": "created",
                "supports_interruption": True,
                "model": "gemini-2.0-flash-live-001"
            }
            
        except Exception as e:
            logger.error(f"Failed to create live session: {e}")
            raise
    
    async def send_audio_and_get_response(
        self,
        session_id: str,
        audio_data: bytes,
        mime_type: str = "audio/pcm"
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """
        Send audio to the Live API session and stream back the response.
        Uses the real bidirectional connection.
        """
        if session_id not in self.active_sessions:
            yield {"type": "error", "message": "Session not found"}
            return
        
        session = self.active_sessions[session_id]
        live_session = session["live_session"]
        session["state"] = LiveSessionState.PROCESSING
        session["is_interrupted"] = False
        
        try:
            # Send audio data through the Live API connection
            await live_session.send(
                input=types.LiveClientRealtimeInput(
                    media_chunks=[
                        types.Blob(
                            data=audio_data,
                            mime_type=mime_type
                        )
                    ]
                )
            )
            
            session["state"] = LiveSessionState.SPEAKING
            
            # Receive streaming response from Live API
            full_text = ""
            audio_chunks = []
            
            async for response in live_session.receive():
                # Check for interruption
                if session.get("is_interrupted"):
                    yield {"type": "interrupted", "message": "Response interrupted"}
                    break
                
                server_content = response.server_content
                if server_content:
                    # Process response parts
                    if server_content.model_turn and server_content.model_turn.parts:
                        for part in server_content.model_turn.parts:
                            if part.text:
                                full_text += part.text
                                yield {
                                    "type": "text_chunk",
                                    "content": part.text
                                }
                            
                            if part.inline_data:
                                audio_b64 = base64.b64encode(part.inline_data.data).decode('utf-8')
                                audio_chunks.append(audio_b64)
                                yield {
                                    "type": "audio_chunk",
                                    "data": audio_b64,
                                    "mime_type": part.inline_data.mime_type
                                }
                    
                    # Check if turn is complete
                    if server_content.turn_complete:
                        break
            
            if not session.get("is_interrupted"):
                yield {
                    "type": "complete",
                    "content": full_text,
                    "audio_chunks": audio_chunks
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
        """Send text to the Live API session and stream back the response"""
        if session_id not in self.active_sessions:
            yield {"type": "error", "message": "Session not found"}
            return
        
        session = self.active_sessions[session_id]
        live_session = session["live_session"]
        session["state"] = LiveSessionState.PROCESSING
        session["is_interrupted"] = False
        
        try:
            # Send text through the Live API connection
            await live_session.send(
                input=text,
                end_of_turn=True
            )
            
            session["state"] = LiveSessionState.SPEAKING
            
            full_response = ""
            audio_chunks = []
            
            async for response in live_session.receive():
                if session.get("is_interrupted"):
                    yield {"type": "interrupted", "message": "Response interrupted"}
                    break
                
                server_content = response.server_content
                if server_content:
                    if server_content.model_turn and server_content.model_turn.parts:
                        for part in server_content.model_turn.parts:
                            if part.text:
                                full_response += part.text
                                yield {
                                    "type": "text_chunk",
                                    "content": part.text
                                }
                            
                            if part.inline_data:
                                audio_b64 = base64.b64encode(part.inline_data.data).decode('utf-8')
                                audio_chunks.append(audio_b64)
                                yield {
                                    "type": "audio_chunk",
                                    "data": audio_b64,
                                    "mime_type": part.inline_data.mime_type
                                }
                    
                    if server_content.turn_complete:
                        break
            
            if not session.get("is_interrupted"):
                yield {
                    "type": "complete",
                    "content": full_response,
                    "audio_chunks": audio_chunks
                }
            
            session["state"] = LiveSessionState.IDLE
            
        except Exception as e:
            logger.error(f"Error sending text: {e}")
            yield {"type": "error", "message": str(e)}
            session["state"] = LiveSessionState.IDLE
    
    async def interrupt(self, session_id: str) -> bool:
        """
        Interrupt the current response (barge-in).
        The Live API natively supports interruption.
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
        """End a live session and close the Live API connection"""
        if session_id not in self.active_sessions:
            return False
        
        try:
            session = self.active_sessions[session_id]
            live_session = session.get("live_session")
            
            # Close the Live API connection
            if live_session:
                try:
                    await live_session.close()
                except Exception as close_err:
                    logger.warning(f"Error closing live session: {close_err}")
            
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
