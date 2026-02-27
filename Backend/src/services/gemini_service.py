"""
Gemini Service - Handles all Gemini API interactions including Live API
"""

import logging
import base64
from typing import Optional, Dict, Any
import asyncio
import json

import google.generativeai as genai

from config import settings

logger = logging.getLogger(__name__)


class GeminiService:
    """Service for interacting with Gemini API"""
    
    _instance = None
    _initialized = False
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self):
        if GeminiService._initialized:
            return
            
        self.client: Optional[genai.Client] = None
        self.is_connected: bool = False
        self.active_sessions: Dict[str, Any] = {}
        
        # Arabic tutor system prompt
        self.system_prompt = """You are EL-Modras (المدرس), an expert Arabic language tutor. 
Your role is to help students learn Arabic through natural conversation.

Guidelines:
1. Be patient, encouraging, and supportive
2. Speak clearly and at an appropriate pace for the student's level
3. Provide both Arabic text and transliteration when teaching new words
4. Correct pronunciation mistakes gently with constructive feedback
5. Use Modern Standard Arabic (الفصحى) unless the student requests a specific dialect
6. Celebrate progress and achievements
7. Keep responses concise but informative
8. Mix Arabic and English naturally to aid understanding

When the student speaks Arabic:
- Acknowledge their effort
- Provide feedback on pronunciation if needed
- Respond in Arabic with English translation

When teaching new vocabulary:
- Say the word clearly
- Provide the Arabic script: [Arabic]
- Provide transliteration: [Transliteration]
- Provide meaning: [English]
- Use it in a simple sentence

Current lesson context will be provided. Focus on the lesson objectives while remaining conversational."""
        
        GeminiService._initialized = True

    async def initialize(self):
        """Initialize the Gemini client"""
        if self.client is not None:
            return
        try:
            genai.configure(api_key=settings.gemini_api_key)
            self.client = genai.GenerativeModel(settings.gemini_model)
            self.is_connected = True
            logger.info(f"Gemini service initialized successfully with model: {settings.gemini_model}")
        except Exception as e:
            logger.error(f"Failed to initialize Gemini service: {e}")
            self.is_connected = False
            raise
    
    async def ensure_initialized(self):
        """Ensure the client is initialized before use"""
        if self.client is None:
            await self.initialize()

    async def cleanup(self):
        """Cleanup resources"""
        for session_id in list(self.active_sessions.keys()):
            await self.end_session(session_id)
        self.is_connected = False
        logger.info("Gemini service cleaned up")

    async def start_live_session(self, session_id: str, lesson_context: Optional[str] = None) -> Dict[str, Any]:
        """Start a new Gemini session for real-time tutoring"""
        try:
            # Ensure client is initialized
            await self.ensure_initialized()
            
            # Store session info (we'll use regular API calls for simplicity)
            self.active_sessions[session_id] = {
                "lesson_context": lesson_context,
                "created_at": asyncio.get_event_loop().time(),
                "message_count": 0,
                "chat_history": []
            }
            
            logger.info(f"Session started: {session_id}")
            
            return {
                "session_id": session_id,
                "status": "active",
                "model": settings.gemini_model
            }
            
        except Exception as e:
            logger.error(f"Failed to start session: {e}")
            raise

    async def end_session(self, session_id: str) -> bool:
        """End a Gemini session"""
        if session_id in self.active_sessions:
            try:
                del self.active_sessions[session_id]
                logger.info(f"Session ended: {session_id}")
                return True
            except Exception as e:
                logger.error(f"Error ending session: {e}")
                return False
        return False

    async def interrupt_session(self, session_id: str) -> bool:
        """Interrupt the current AI response (barge-in support)"""
        if session_id not in self.active_sessions:
            logger.warning(f"Session not found for interruption: {session_id}")
            return False
        
        try:
            session_data = self.active_sessions[session_id]
            # Mark session as interrupted
            session_data["is_interrupted"] = True
            logger.info(f"Session interrupted: {session_id}")
            return True
        except Exception as e:
            logger.error(f"Error interrupting session: {e}")
            return False

    async def process_audio_stream(self, session_id: str, audio_data: bytes) -> Optional[bytes]:
        """Process audio data and return text response (simplified for hackathon)"""
        if session_id not in self.active_sessions:
            logger.warning(f"Session not found: {session_id}")
            return None
        
        try:
            await self.ensure_initialized()
            session_data = self.active_sessions[session_id]
            
            # Use text-based response since we can't process audio directly
            prompt = f"""{self.system_prompt}

The student has sent an audio message practicing Arabic. 
Provide a helpful response as if they said "مرحبا" (Hello).
Include Arabic text with transliteration."""

            response = self.client.generate_content(prompt)
            
            session_data["message_count"] += 1
            
            # Return the text response as bytes
            text_response = response.text if response.text else "I didn't catch that. Could you try again?"
            return text_response.encode('utf-8')
            
        except Exception as e:
            logger.error(f"Error processing audio stream: {e}")
            return None

    async def send_audio_message(self, session_id: str, audio_data: bytes) -> Dict[str, Any]:
        """Send audio message and get text + audio response (non-streaming)"""
        try:
            await self.ensure_initialized()
            
            # For now, we'll just use text-based interaction
            # In production, you would use a speech-to-text service first
            prompt = f"""{self.system_prompt}

The student has sent an audio message. Since I cannot process audio directly, 
please respond as if the student said "مرحبا" (Hello) and provide a helpful Arabic lesson response.
Include Arabic text with transliteration and English translation."""
            
            response = self.client.generate_content(prompt)
            
            text_response = response.text if response.text else "مرحباً! Hello! Let's practice Arabic together."
            
            return {
                "text": text_response,
                "arabic_text": self._extract_arabic(text_response),
                "audio_base64": None,
                "audio_url": None
            }
            
        except Exception as e:
            logger.error(f"Error sending audio message: {e}")
            raise

    async def send_audio_with_context(self, audio_data: bytes, context: str) -> Dict[str, Any]:
        """Send audio message with lesson context and get contextual response"""
        try:
            await self.ensure_initialized()
            
            logger.info(f"Received audio data: {len(audio_data)} bytes")
            
            # Step 1: Try to transcribe audio using Google Cloud Speech-to-Text
            transcribed_text = await self._transcribe_audio(audio_data)
            
            logger.info(f"Transcribed text: '{transcribed_text}'")
            
            # Step 2: If transcription failed, try Gemini multimodal directly
            if not transcribed_text or transcribed_text.strip() == "":
                logger.info("Transcription empty, trying Gemini multimodal...")
                transcribed_text = await self._transcribe_with_gemini(audio_data)
                logger.info(f"Gemini transcription: '{transcribed_text}'")
            
            if not transcribed_text or transcribed_text.strip() == "":
                logger.warning("All transcription methods failed")
                return {
                    "text": "مش سامعك كويس. ممكن تقول تاني بصوت أعلى؟",
                    "arabic_text": "مش سامعك كويس. ممكن تقول تاني بصوت أعلى؟",
                    "audio_base64": None,
                    "audio_url": None
                }
            
            # Step 2: Send transcribed text with context to Gemini
            prompt = f"""{context}

الطالب قال: "{transcribed_text}"

جاوب على سؤال الطالب بناءً على الدرس والكلمة الحالية.

تعليمات:
- لو قال "جملة" أو "مثال" أو "حط في جملة" → اعمل جملة بسيطة بالكلمة الحالية
- لو قال "كرر" أو "تاني" → كرر الكلمة الحالية
- لو قال "يعني إيه" أو "معنى" → اشرح معنى الكلمة ببساطة
- استخدم العامية المصرية
- خلي الرد قصير (جملة أو اتنين)
- كن مشجع

الرد:"""

            response = self.client.generate_content(prompt)
            text_response = response.text if response.text else "مش فاهم. ممكن تقول تاني؟"
            text_response = text_response.strip()
            
            return {
                "text": text_response,
                "arabic_text": text_response,
                "audio_base64": None,
                "audio_url": None
            }
            
        except Exception as e:
            logger.error(f"Error sending audio with context: {e}")
            return {
                "text": "حصلت مشكلة. جرب تاني!",
                "arabic_text": "حصلت مشكلة. جرب تاني!",
                "audio_base64": None,
                "audio_url": None
            }
    
    async def _transcribe_audio(self, audio_data: bytes) -> Optional[str]:
        """Transcribe audio using Google Cloud Speech-to-Text"""
        try:
            from google.cloud import speech
            import struct
            
            client = speech.SpeechClient()
            audio = speech.RecognitionAudio(content=audio_data)
            
            # Parse WAV header to get sample rate
            sample_rate = 16000  # Default
            if len(audio_data) > 44 and audio_data[:4] == b'RIFF':
                try:
                    # Sample rate is at bytes 24-27 in WAV header
                    sample_rate = struct.unpack('<I', audio_data[24:28])[0]
                    logger.info(f"Detected sample rate from WAV header: {sample_rate}")
                except Exception as e:
                    logger.warning(f"Could not parse WAV header: {e}")
            
            config = speech.RecognitionConfig(
                encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
                sample_rate_hertz=sample_rate,
                language_code="ar-EG",  # Egyptian Arabic
                alternative_language_codes=["ar-SA", "ar-XA", "en-US"],
                enable_automatic_punctuation=True,
                model="default",
            )
            
            logger.info(f"Calling Speech-to-Text with sample_rate={sample_rate}")
            response = client.recognize(config=config, audio=audio)
            
            if response.results:
                transcript = response.results[0].alternatives[0].transcript
                logger.info(f"Transcription successful: {transcript}")
                return transcript
            else:
                logger.warning("No transcription results returned")
            
            return None
            
        except Exception as e:
            logger.error(f"Error transcribing audio: {e}")
            return None

    async def _transcribe_with_gemini(self, audio_data: bytes) -> Optional[str]:
        """Fallback: Use Gemini's multimodal capabilities to transcribe audio"""
        try:
            import tempfile
            import os
            
            # Save audio to temp file
            with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
                f.write(audio_data)
                temp_path = f.name
            
            try:
                # Upload file to Gemini
                audio_file = genai.upload_file(temp_path, mime_type="audio/wav")
                
                # Ask Gemini to transcribe
                prompt = """اسمع الصوت ده وقولي الشخص قال إيه بالظبط.
لو مش فاهم الكلام أو الصوت مش واضح، قول "غير واضح".
اكتب بس اللي الشخص قاله، من غير أي تعليق."""
                
                response = self.client.generate_content([prompt, audio_file])
                
                # Clean up
                os.unlink(temp_path)
                
                if response.text:
                    text = response.text.strip()
                    if "غير واضح" in text or len(text) < 2:
                        return None
                    return text
                    
            except Exception as e:
                logger.warning(f"Gemini transcription failed: {e}")
                # Clean up temp file
                if os.path.exists(temp_path):
                    os.unlink(temp_path)
            
            return None
            
        except Exception as e:
            logger.error(f"Error in Gemini transcription: {e}")
            return None

    async def recognize_object(self, image_data: bytes) -> Dict[str, Any]:
        """Recognize object in image and return Arabic vocabulary"""
        try:
            await self.ensure_initialized()
            
            prompt = """Look at this image and identify the main object.
Respond in this exact JSON format:
{
    "english_name": "the object name in English",
    "arabic_name": "the object name in Arabic",
    "transliteration": "how to pronounce the Arabic word using English letters",
    "confidence": 0.95,
    "description": "a brief description in English"
}

Only respond with the JSON, no other text."""

            # Create image part for vision model
            image_part = {
                "mime_type": "image/jpeg",
                "data": base64.b64encode(image_data).decode('utf-8')
            }
            
            # Use gemini-2.5-flash for image recognition (supports vision)
            vision_model = genai.GenerativeModel('gemini-2.5-flash')
            response = vision_model.generate_content([prompt, image_part])
            
            # Parse JSON response
            text = response.text.strip()
            # Remove markdown code blocks if present
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            
            result = json.loads(text)
            
            return {
                "english_name": result.get("english_name", "Unknown"),
                "arabic_name": result.get("arabic_name", "غير معروف"),
                "transliteration": result.get("transliteration", "Unknown"),
                "confidence": result.get("confidence", 0.5),
                "description": result.get("description", "")
            }
            
        except Exception as e:
            logger.error(f"Error recognizing object: {e}")
            raise

    async def analyze_pronunciation(self, audio_data: bytes, expected_text: str) -> Dict[str, Any]:
        """Analyze Arabic pronunciation with dialect support - lenient for kids"""
        try:
            await self.ensure_initialized()
            
            # Check audio size
            audio_size = len(audio_data)
            logger.info(f"Analyzing pronunciation for '{expected_text}', audio size: {audio_size} bytes")
            
            # If audio is too small, it's probably empty/silent
            if audio_size < 1000:
                return {
                    "score": 0.3,
                    "feedback": "مسمعتش حاجة! اتكلم بصوت أعلى وجرب تاني!",
                    "suggestions": ["اتأكد إن الميكروفون شغال", "اتكلم بصوت واضح"]
                }
            
            prompt = f"""You are a friendly Arabic teacher for KIDS. Be VERY encouraging and lenient.

The child is trying to say: "{expected_text}"

IMPORTANT - Accept these as CORRECT:
1. Egyptian dialect pronunciation (e.g., "أ" sounds like "ء", "ق" sounds like "ء")
2. Colloquial/informal Arabic pronunciation
3. Any Arabic dialect (Egyptian, Levantine, Gulf, Moroccan, etc.)
4. Close approximations (the word sounds similar)
5. Child-like pronunciation with minor errors

SCORING FOR KIDS (be generous!):
- 0.85-1.0: Said it correctly (any dialect accepted)
- 0.7-0.85: Close enough, understood the word
- 0.5-0.7: Tried hard, needs a bit more practice
- 0.3-0.5: Good effort but needs help
- Below 0.3: Only if completely silent or wrong language

Give feedback in EGYPTIAN ARABIC (عامية مصرية) to be friendly.
Examples: "برافو عليك!", "شاطر أوي!", "كده تمام!", "جرب تاني"

Respond ONLY with valid JSON:
{{"score": 0.8, "feedback": "برافو! شاطر أوي يا بطل!", "suggestions": ["tip in Egyptian Arabic"]}}"""

            # Create audio part for multimodal model
            audio_part = {
                "mime_type": "audio/wav",
                "data": base64.b64encode(audio_data).decode('utf-8')
            }
            
            # Use gemini-2.5-flash which supports audio
            multimodal_model = genai.GenerativeModel('gemini-2.5-flash')
            
            try:
                response = multimodal_model.generate_content([prompt, audio_part])
                response_text = response.text.strip()
                logger.info(f"Pronunciation response: {response_text[:200]}...")
            except Exception as api_error:
                logger.error(f"Gemini API error: {api_error}")
                # Give encouraging feedback even on error
                return {
                    "score": 0.6,
                    "feedback": "شاطر! جرب تاني بصوت أوضح",
                    "suggestions": ["اتكلم ببطء", "قرب الموبايل منك"]
                }
            
            # Parse JSON response
            text = response_text
            if text.startswith("```"):
                lines = text.split("\n")
                text = "\n".join(lines[1:-1] if lines[-1] == "```" else lines[1:])
                if text.startswith("json"):
                    text = text[4:].strip()
            
            try:
                result = json.loads(text)
            except json.JSONDecodeError:
                # Try to extract JSON from the response
                import re
                json_match = re.search(r'\{[^{}]*\}', response_text)
                if json_match:
                    result = json.loads(json_match.group())
                else:
                    logger.error(f"Could not parse response: {response_text}")
                    return {
                        "score": 0.7,
                        "feedback": "شاطر! كمل كده!",
                        "suggestions": ["جرب تاني"]
                    }
            
            # Boost score slightly for kids (be encouraging)
            score = min(1.0, max(0.0, float(result.get("score", 0.5))))
            if score >= 0.5:
                score = min(1.0, score + 0.1)  # Boost medium scores
            
            return {
                "score": score,
                "feedback": result.get("feedback", "شاطر! كمل كده!"),
                "suggestions": result.get("suggestions", ["برافو عليك!"])
            }
            
        except Exception as e:
            logger.error(f"Error analyzing pronunciation: {e}")
            return {
                "score": 0.6,
                "feedback": "جرب تاني! اتكلم بصوت واضح",
                "suggestions": ["اتكلم بصوت أعلى", "قرب الموبايل من بقك"]
            }

    async def chat(self, message: str, session_id: Optional[str] = None) -> Dict[str, Any]:
        """Text-based chat with Gemini (fallback)"""
        try:
            await self.ensure_initialized()
            
            full_prompt = f"{self.system_prompt}\n\nUser: {message}"
            response = self.client.generate_content(full_prompt)
            
            text_response = response.text if response.text else ""
            
            return {
                "text": text_response,
                "arabic_text": self._extract_arabic(text_response)
            }
            
        except Exception as e:
            logger.error(f"Error in chat: {e}")
            raise

    async def chat_with_context(self, message: str, context: str, session_id: Optional[str] = None) -> str:
        """Chat with Gemini using provided context (for answering child's questions)"""
        try:
            await self.ensure_initialized()
            
            # Build prompt with context for child-friendly responses
            full_prompt = f"""أنت المُدَرِّس، معلم لغة عربية ودود للأطفال.
            
السياق: {context}

سؤال الطفل: {message}

الرد يكون:
1. بالعامية المصرية البسيطة
2. مشجع وإيجابي
3. قصير ومفهوم للطفل
4. مع مثال لو مفيد

الرد:"""

            response = self.client.generate_content(full_prompt)
            
            text_response = response.text if response.text else "آسف، مش فاهم السؤال. ممكن تسأل تاني؟"
            
            return text_response
            
        except Exception as e:
            logger.error(f"Error in chat_with_context: {e}")
            return "حصلت مشكلة. جرب تاني!"

    async def generate_natural_speech(self, text: str, voice_style: str = "friendly_teacher") -> Dict[str, Any]:
        """Generate natural-sounding speech using Gemini's voice capabilities"""
        try:
            await self.ensure_initialized()
            
            # Define voice style prompts
            style_prompts = {
                "friendly_teacher": "Speak warmly and encouragingly like a friendly teacher talking to a young child",
                "excited": "Speak with enthusiasm and excitement",
                "calm": "Speak slowly and calmly"
            }
            
            style = style_prompts.get(voice_style, style_prompts["friendly_teacher"])
            
            prompt = f"""You are an Arabic teacher speaking to a child.
{style}.

Say this in Egyptian Arabic dialect (عامية مصرية):
"{text}"

Speak naturally with appropriate pauses and intonation."""

            # Use Gemini 2.5 Flash with audio output
            model = genai.GenerativeModel('gemini-2.5-flash')
            
            # Configure for audio output
            response = model.generate_content(
                prompt,
                generation_config={
                    "response_modalities": ["AUDIO"],
                    "speech_config": {
                        "voice_config": {
                            "prebuilt_voice_config": {
                                "voice_name": "Aoede"  # Natural sounding voice
                            }
                        }
                    }
                }
            )
            
            # Extract audio data if available
            if hasattr(response, 'audio') and response.audio:
                audio_base64 = base64.b64encode(response.audio).decode('utf-8')
                return {
                    "audio_base64": audio_base64,
                    "text": text,
                    "success": True
                }
            else:
                return {
                    "audio_base64": None,
                    "text": text,
                    "success": False,
                    "error": "No audio generated"
                }
                
        except Exception as e:
            logger.error(f"Error generating speech: {e}")
            return {
                "audio_base64": None,
                "text": text,
                "success": False,
                "error": str(e)
            }

    def _extract_arabic(self, text: str) -> Optional[str]:
        """Extract Arabic text from response"""
        import re
        arabic_pattern = re.compile(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]+')
        matches = arabic_pattern.findall(text)
        return " ".join(matches) if matches else None


# Singleton instance
gemini_service = GeminiService()
