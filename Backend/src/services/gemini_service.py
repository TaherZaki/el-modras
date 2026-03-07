"""
Gemini Service - Handles all Gemini API interactions using Google GenAI SDK
Uses the new `google-genai` SDK (from google import genai)
"""

import logging
import base64
from typing import Optional, Dict, Any
import asyncio
import json
import re
import struct

from google import genai
from google.genai import types

from config import settings

logger = logging.getLogger(__name__)


class GeminiService:
    """Service for interacting with Gemini API using the new Google GenAI SDK"""
    
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
        """Initialize the Gemini client using new google-genai SDK"""
        if self.client is not None:
            return
        try:
            self.client = genai.Client(api_key=settings.gemini_api_key)
            self.is_connected = True
            logger.info(f"Gemini initialized, model: {settings.gemini_model}")
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
            await self.ensure_initialized()
            
            self.active_sessions[session_id] = {
                "lesson_context": lesson_context,
                "created_at": asyncio.get_event_loop().time(),
                "message_count": 0,
                "chat_history": [],
                "is_interrupted": False
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
            session_data["is_interrupted"] = True
            logger.info(f"Session interrupted: {session_id}")
            return True
        except Exception as e:
            logger.error(f"Error interrupting session: {e}")
            return False

    async def process_audio_stream(self, session_id: str, audio_data: bytes) -> Optional[bytes]:
        """Process audio data and return text response"""
        if session_id not in self.active_sessions:
            logger.warning(f"Session not found: {session_id}")
            return None
        
        try:
            await self.ensure_initialized()
            session_data = self.active_sessions[session_id]
            
            response = await asyncio.to_thread(
                self.client.models.generate_content,
                model=settings.gemini_model,
                contents=self.system_prompt + "\n\nThe student has sent an audio message practicing Arabic. Provide a helpful response.",
                config=types.GenerateContentConfig(
                    system_instruction=self.system_prompt
                )
            )
            
            session_data["message_count"] += 1
            text_response = response.text if response.text else "I didn't catch that. Could you try again?"
            return text_response.encode('utf-8')
            
        except Exception as e:
            logger.error(f"Error processing audio stream: {e}")
            return None

    async def send_audio_message(self, session_id: str, audio_data: bytes) -> Dict[str, Any]:
        """Send audio message and get text response"""
        try:
            await self.ensure_initialized()
            
            # Use Gemini multimodal with audio
            audio_part = types.Part.from_bytes(
                data=audio_data,
                mime_type="audio/wav"
            )
            
            response = await asyncio.to_thread(
                self.client.models.generate_content,
                model=settings.gemini_model,
                contents=[
                    types.Content(
                        parts=[
                            types.Part.from_text(self.system_prompt + "\n\nListen to this audio and respond as an Arabic teacher."),
                            audio_part
                        ]
                    )
                ]
            )
            
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
        """Send audio message with lesson context and get contextual response WITH audio.
        Does transcribe + answer + TTS in ONE call to minimize latency.
        """
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
                fallback_text = "مش سامعك كويس. ممكن تقول تاني بصوت أعلى؟"
                # Generate TTS for fallback too
                tts_result = await self.generate_natural_speech(fallback_text)
                return {
                    "text": fallback_text,
                    "arabic_text": fallback_text,
                    "audio_base64": tts_result.get("audio_base64"),
                    "audio_url": None
                }
            
            # Step 3: Send transcribed text with context to Gemini
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

            response = await asyncio.to_thread(
                self.client.models.generate_content,
                model=settings.gemini_model,
                contents=prompt
            )
            
            text_response = response.text if response.text else "مش فاهم. ممكن تقول تاني؟"
            text_response = text_response.strip()
            
            # Step 4: Generate TTS audio for the response (in same call!)
            logger.info(f"Generating TTS for response: {text_response[:50]}...")
            tts_result = await self.generate_natural_speech(text_response)
            audio_base64 = tts_result.get("audio_base64") if tts_result.get("success") else None
            
            return {
                "text": text_response,
                "arabic_text": text_response,
                "audio_base64": audio_base64,
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
            
            client = speech.SpeechClient()
            audio = speech.RecognitionAudio(content=audio_data)
            
            # Parse WAV header to get sample rate
            sample_rate = 16000
            if len(audio_data) > 44 and audio_data[:4] == b'RIFF':
                try:
                    sample_rate = struct.unpack('<I', audio_data[24:28])[0]
                    logger.info(f"Detected sample rate from WAV header: {sample_rate}")
                except Exception as e:
                    logger.warning(f"Could not parse WAV header: {e}")
            
            config = speech.RecognitionConfig(
                encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
                sample_rate_hertz=sample_rate,
                language_code="ar-EG",
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
            audio_part = types.Part.from_bytes(
                data=audio_data,
                mime_type="audio/wav"
            )
            
            prompt = """اسمع الصوت ده وقولي الشخص قال إيه بالظبط.
لو مش فاهم الكلام أو الصوت مش واضح، قول "غير واضح".
اكتب بس اللي الشخص قاله، من غير أي تعليق."""
            
            response = await asyncio.to_thread(
                self.client.models.generate_content,
                model=settings.gemini_model,
                contents=[
                    types.Content(
                        parts=[
                            types.Part.from_text(prompt),
                            audio_part
                        ]
                    )
                ]
            )
            
            if response.text:
                text = response.text.strip()
                if "غير واضح" in text or len(text) < 2:
                    return None
                return text
            
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

            image_part = types.Part.from_bytes(
                data=image_data,
                mime_type="image/jpeg"
            )
            
            response = await asyncio.to_thread(
                self.client.models.generate_content,
                model=settings.gemini_model,
                contents=[
                    types.Content(
                        parts=[
                            types.Part.from_text(prompt),
                            image_part
                        ]
                    )
                ]
            )
            
            # Parse JSON response
            text = response.text.strip()
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
            
            audio_size = len(audio_data)
            logger.info(f"Analyzing pronunciation for '{expected_text}', audio size: {audio_size} bytes")
            
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

            audio_part = types.Part.from_bytes(
                data=audio_data,
                mime_type="audio/wav"
            )
            
            try:
                response = await asyncio.to_thread(
                    self.client.models.generate_content,
                    model=settings.gemini_model,
                    contents=[
                        types.Content(
                            parts=[
                                types.Part.from_text(prompt),
                                audio_part
                            ]
                        )
                    ]
                )
                response_text = response.text.strip()
                logger.info(f"Pronunciation response: {response_text[:200]}...")
            except Exception as api_error:
                logger.error(f"Gemini API error: {api_error}")
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
            
            # Boost score slightly for kids
            score = min(1.0, max(0.0, float(result.get("score", 0.5))))
            if score >= 0.5:
                score = min(1.0, score + 0.1)
            
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
        """Text-based chat with Gemini"""
        try:
            await self.ensure_initialized()
            
            response = await asyncio.to_thread(
                self.client.models.generate_content,
                model=settings.gemini_model,
                contents=f"{self.system_prompt}\n\nUser: {message}"
            )
            
            text_response = response.text if response.text else ""
            
            return {
                "text": text_response,
                "arabic_text": self._extract_arabic(text_response)
            }
            
        except Exception as e:
            logger.error(f"Error in chat: {e}")
            raise

    async def chat_with_context(self, message: str, context: str, session_id: Optional[str] = None) -> str:
        """Chat with Gemini using provided context"""
        try:
            await self.ensure_initialized()
            
            full_prompt = f"""أنت المُدَرِّس، معلم لغة عربية ودود للأطفال.
            
السياق: {context}

سؤال الطفل: {message}

الرد يكون:
1. بالعامية المصرية البسيطة
2. مشجع وإيجابي
3. قصير ومفهوم للطفل
4. مع مثال لو مفيد

الرد:"""

            response = await asyncio.to_thread(
                self.client.models.generate_content,
                model=settings.gemini_model,
                contents=full_prompt
            )
            
            text_response = response.text if response.text else "آسف، مش فاهم السؤال. ممكن تسأل تاني؟"
            return text_response
            
        except Exception as e:
            logger.error(f"Error in chat_with_context: {e}")
            return "حصلت مشكلة. جرب تاني!"

    async def generate_natural_speech(self, text: str, voice_style: str = "friendly_teacher") -> Dict[str, Any]:
        """Generate natural-sounding speech using Gemini TTS (Orus voice).
        Retries once on transient failures.
        """
        await self.ensure_initialized()
        last_error = None
        
        for attempt in range(1, 3):  # 2 attempts
            try:
                prompt = f"""انت مدرس عربي مصري اسمك أستاذ نور، بتعلم أطفال صغيرين.
اتكلم بعامية مصرية طبيعية وبسلاسة، زي ما بتكلم طفل في أوضة الفصل.
صوتك دافي ومشجع.

قول بالظبط كده: {text}"""

                response = await asyncio.to_thread(
                    self.client.models.generate_content,
                    model=settings.gemini_tts_model,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        response_modalities=["AUDIO"],
                        speech_config=types.SpeechConfig(
                            voice_config=types.VoiceConfig(
                                prebuilt_voice_config=types.PrebuiltVoiceConfig(
                                    voice_name="Orus"
                                )
                            )
                        )
                    )
                )
                
                if response.candidates and response.candidates[0].content.parts:
                    for part in response.candidates[0].content.parts:
                        if part.inline_data and part.inline_data.mime_type.startswith("audio/"):
                            raw_audio = part.inline_data.data
                            logger.info(f"TTS attempt {attempt} returned {len(raw_audio)} bytes for: {text[:30]}...")
                            
                            wav_audio = self._pcm_to_wav(raw_audio, sample_rate=24000, channels=1, bits_per_sample=16)
                            
                            audio_base64 = base64.b64encode(wav_audio).decode('utf-8')
                            return {
                                "audio_base64": audio_base64,
                                "text": text,
                                "success": True
                            }
                
                logger.warning(f"TTS attempt {attempt} no audio for: {text[:30]}...")
                    
            except Exception as e:
                last_error = e
                logger.warning(f"TTS attempt {attempt} error: {e}")
                if attempt < 2:
                    await asyncio.sleep(0.5)
        
        logger.error(f"TTS failed after 2 attempts for: {text[:30]}... last error: {last_error}")
        return {
            "audio_base64": None,
            "text": text,
            "success": False,
            "error": str(last_error) if last_error else "No audio generated"
        }

    @staticmethod
    def _pcm_to_wav(pcm_data: bytes, sample_rate: int = 24000, channels: int = 1, bits_per_sample: int = 16) -> bytes:
        """Convert raw PCM audio data to WAV format with proper header"""
        import io
        import wave
        
        buffer = io.BytesIO()
        with wave.open(buffer, 'wb') as wav_file:
            wav_file.setnchannels(channels)
            wav_file.setsampwidth(bits_per_sample // 8)
            wav_file.setframerate(sample_rate)
            wav_file.writeframes(pcm_data)
        
        return buffer.getvalue()

    async def generate_story_image(self, prompt: str) -> Dict[str, Any]:
        """Generate an image for interactive stories using Gemini's image generation"""
        try:
            await self.ensure_initialized()
            
            image_prompt = f"""Generate a colorful, child-friendly cartoon illustration for a children's Arabic learning storybook.
Scene: {prompt}
Style: Bright colors, friendly cartoon characters, simple shapes, suitable for children aged 4-8.
No text in the image."""

            response = await asyncio.to_thread(
                self.client.models.generate_content,
                model=settings.gemini_image_model,
                contents=image_prompt,
                config=types.GenerateContentConfig(
                    response_modalities=["TEXT", "IMAGE"]
                )
            )
            
            # Extract image from response
            if response.candidates and response.candidates[0].content.parts:
                for part in response.candidates[0].content.parts:
                    if part.inline_data and part.inline_data.mime_type.startswith("image/"):
                        image_base64 = base64.b64encode(part.inline_data.data).decode('utf-8')
                        return {
                            "image_base64": image_base64,
                            "mime_type": part.inline_data.mime_type,
                            "success": True
                        }
            
            return {
                "image_base64": None,
                "success": False,
                "error": "No image generated"
            }
            
        except Exception as e:
            logger.error(f"Error generating story image: {e}")
            return {
                "image_base64": None,
                "success": False,
                "error": str(e)
            }

    def _extract_arabic(self, text: str) -> Optional[str]:
        """Extract Arabic text from response"""
        arabic_pattern = re.compile(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]+')
        matches = arabic_pattern.findall(text)
        return " ".join(matches) if matches else None


# Singleton instance
gemini_service = GeminiService()
