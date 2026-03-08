"""
EL-Modras ADK Agent - Arabic Language Tutor Agent
Built using Google Agent Development Kit (ADK)

This agent orchestrates the Arabic tutoring experience using:
- Gemini Live API for real-time voice conversation
- Vision for camera-based vocabulary learning
- Pronunciation analysis with audio input
- Interactive story generation with images
"""

import logging
from typing import Optional, Dict, Any

from google import genai
from google.adk import Agent, Runner
from google.adk.sessions import InMemorySessionService
from google.adk.tools import FunctionTool
from google.genai import types

from config import settings

logger = logging.getLogger(__name__)


# ============================================================
# Tool Functions for the ADK Agent
# ============================================================

async def teach_word(word_arabic: str, word_english: str, transliteration: str) -> dict:
    """Teach a new Arabic word to the student with pronunciation guide.
    
    Args:
        word_arabic: The word in Arabic script
        word_english: The English translation  
        transliteration: How to pronounce using English letters
        
    Returns:
        Teaching response with word details and example sentence
    """
    return {
        "word": word_arabic,
        "translation": word_english,
        "transliteration": transliteration,
        "action": "teach_word",
        "instructions": f"Say the word '{word_arabic}' ({transliteration}) clearly and encourage the student to repeat it."
    }


async def evaluate_pronunciation(student_audio_text: str, expected_word: str) -> dict:
    """Evaluate the student's pronunciation attempt.
    
    Args:
        student_audio_text: What the student said (transcribed)
        expected_word: The word they were supposed to say
        
    Returns:
        Evaluation with score and feedback
    """
    # Simple similarity check
    is_correct = student_audio_text.strip() == expected_word.strip()
    score = 0.9 if is_correct else 0.4
    
    return {
        "score": score,
        "is_correct": is_correct,
        "expected": expected_word,
        "heard": student_audio_text,
        "feedback": "برافو عليك يا بطل! 🌟" if is_correct else f"قريب! جرب تاني: {expected_word}"
    }


async def generate_story_scene(scene_description: str, characters: str, vocabulary_word: str) -> dict:
    """Generate an interactive story scene for vocabulary learning.
    
    Args:
        scene_description: Description of what happens in this scene
        characters: Characters involved in the scene
        vocabulary_word: The Arabic word to teach in this scene
        
    Returns:
        Story scene with narration and vocabulary integration
    """
    return {
        "scene": scene_description,
        "characters": characters,
        "vocabulary_word": vocabulary_word,
        "action": "narrate_scene",
        "instructions": f"Narrate the scene in Egyptian Arabic, then teach the word '{vocabulary_word}'"
    }


async def recognize_object_in_image(object_description: str) -> dict:
    """Process the recognized object from camera and teach its Arabic name.
    
    Args:
        object_description: Description of the object seen in camera
        
    Returns:
        Arabic vocabulary for the object
    """
    return {
        "object": object_description,
        "action": "teach_camera_word",
        "instructions": f"Teach the Arabic name for '{object_description}' with pronunciation and example sentence"
    }


async def track_progress(words_learned: int, lesson_name: str, score: float) -> dict:
    """Track the student's learning progress.
    
    Args:
        words_learned: Number of words learned in this session
        lesson_name: Name of the current lesson
        score: Average pronunciation score
        
    Returns:
        Progress update with encouragement
    """
    stars = int(score * 5)
    return {
        "words_learned": words_learned,
        "lesson": lesson_name,
        "score": score,
        "stars": stars,
        "message": f"شاطر! اتعلمت {words_learned} كلمات جديدة! ⭐️ x {stars}"
    }


async def get_lesson_content(category: str, level: str) -> dict:
    """Get lesson content for a specific category and level.
    
    Args:
        category: Lesson category (greetings, numbers, colors, food, animals, family)
        level: Student level (beginner, intermediate, advanced)
        
    Returns:
        Lesson content with words and activities
    """
    return {
        "category": category,
        "level": level,
        "action": "load_lesson",
        "instructions": f"Load and teach the {category} lesson at {level} level"
    }


# ============================================================
# ADK Agent Definition
# ============================================================

# System instruction for the Arabic tutor agent
TUTOR_SYSTEM_INSTRUCTION = """أنت نور، معلم لغة عربية ذكي ودود للأطفال.
اسمك نور ولو حد سألك قولّه "أنا نور، المدرس بتاعك!"

## شخصيتك:
- أنت معلم مصري ودود ومرح اسمك نور
- بتحب تشجع الأطفال وتفرح بنجاحهم
- بتستخدم العامية المصرية البسيطة
- صبور جداً ومتفاهم

## مهامك:
1. **تعليم الكلمات**: علم كلمات عربية جديدة بالنطق والمعنى
2. **تقييم النطق**: قيم نطق الطالب وشجعه
3. **القصص التفاعلية**: احكي قصص ممتعة تعلم كلمات جديدة
4. **التعلم بالكاميرا**: لما الطالب يصور حاجة، علمه اسمها بالعربي
5. **تتبع التقدم**: تابع تقدم الطالب وشجعه

## قواعد مهمة:
- استخدم جمل قصيرة وبسيطة
- كل كلمة جديدة → انطقها → اطلب التكرار → شجع
- لو الطفل غلط → صحح بلطف: "قريب! جرب تاني"
- لو الطفل صح → احتفل: "برافو عليك يا بطل! 🌟"
- كلم الطفل بالعامية المصرية

You are Nour (نور), an AI Arabic language tutor for kids.
Use the available tools to teach, evaluate, and track progress.
Always be encouraging and patient. Speak in Egyptian Arabic dialect.
If asked your name, say "أنا نور، المدرس بتاعك!" """


def create_tutor_agent() -> Agent:
    """
    Create the EL-Modras Arabic Tutor ADK Agent.
    
    This agent uses Google ADK (Agent Development Kit) to orchestrate
    multi-step tutoring workflows including:
    - Teaching new vocabulary with pronunciation
    - Evaluating student pronunciation attempts
    - Generating interactive story scenes
    - Processing camera-based object recognition
    - Tracking learning progress
    """
    
    # Define tools for the agent
    tools = [
        FunctionTool(func=teach_word),
        FunctionTool(func=evaluate_pronunciation),
        FunctionTool(func=generate_story_scene),
        FunctionTool(func=recognize_object_in_image),
        FunctionTool(func=track_progress),
        FunctionTool(func=get_lesson_content),
    ]
    
    # Create the ADK Agent
    agent = Agent(
        model="gemini-2.5-flash",
        name="el_modras_tutor",
        description="EL-Modras: AI Arabic Language Tutor for Kids - teaches Arabic through voice, camera, and interactive stories",
        instruction=TUTOR_SYSTEM_INSTRUCTION,
        tools=tools,
    )
    
    return agent


class ADKTutorService:
    """
    Service wrapper for the ADK Agent.
    Manages agent lifecycle and provides API for the FastAPI routers.
    """
    
    _instance = None
    _initialized = False
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self):
        if ADKTutorService._initialized:
            return
        
        self.agent: Optional[Agent] = None
        self.runner: Optional[Runner] = None
        self.active_sessions: Dict[str, Any] = {}
        self.is_initialized = False
        ADKTutorService._initialized = True
    
    async def initialize(self):
        """Initialize the ADK agent"""
        if self.is_initialized:
            return
        
        try:
            self.agent = create_tutor_agent()
            self.session_service = InMemorySessionService()
            self.runner = Runner(
                agent=self.agent,
                app_name="el_modras",
                session_service=self.session_service,
            )
            self.is_initialized = True
            logger.info("ADK Tutor Agent initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize ADK Agent: {e}")
            raise
    
    async def ensure_initialized(self):
        """Ensure agent is initialized"""
        if not self.is_initialized:
            await self.initialize()
    
    async def process_message(
        self,
        session_id: str,
        message: str,
        context: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Process a message through the ADK agent.
        The agent will use its tools to handle the tutoring task.
        """
        try:
            await self.ensure_initialized()
            
            # Add context if provided
            full_message = message
            if context:
                full_message = f"[Context: {context}]\n\n{message}"
            
            # Ensure session exists
            session = await self.session_service.get_session(
                app_name="el_modras",
                user_id=session_id,
                session_id=session_id
            )
            if session is None:
                session = await self.session_service.create_session(
                    app_name="el_modras",
                    user_id=session_id,
                    session_id=session_id
                )
            
            # Run the agent - run_async returns an async generator of Events
            result_text = ""
            tool_calls = []
            
            content = types.Content(
                parts=[types.Part.from_text(full_message)],
                role="user"
            )
            
            async for event in self.runner.run_async(
                user_id=session_id,
                session_id=session_id,
                new_message=content
            ):
                if event.content and event.content.parts:
                    for part in event.content.parts:
                        if part.text:
                            result_text += part.text
                        if hasattr(part, 'function_call') and part.function_call:
                            tool_calls.append({
                                "name": part.function_call.name,
                                "args": dict(part.function_call.args) if part.function_call.args else {}
                            })
            
            return {
                "text": result_text,
                "tool_calls": tool_calls,
                "session_id": session_id
            }
            
        except Exception as e:
            logger.error(f"Error processing ADK message: {e}")
            return {
                "text": "حصلت مشكلة. جرب تاني!",
                "tool_calls": [],
                "session_id": session_id
            }
    
    async def teach_lesson(
        self,
        session_id: str,
        category: str,
        words: list
    ) -> Dict[str, Any]:
        """Use the agent to teach a lesson with specific words"""
        words_str = ", ".join([f"{w.get('arabic', '')} ({w.get('english', '')})" for w in words])
        message = f"ابدأ درس {category}. الكلمات: {words_str}. علم كل كلمة واحدة واحدة."
        return await self.process_message(session_id, message, context=f"Lesson: {category}")
    
    async def evaluate_student(
        self,
        session_id: str,
        expected_word: str,
        student_said: str
    ) -> Dict[str, Any]:
        """Use the agent to evaluate pronunciation"""
        message = f"الطالب حاول يقول '{expected_word}' وقال '{student_said}'. قيم النطق وشجعه."
        return await self.process_message(session_id, message)
    
    async def cleanup(self):
        """Cleanup resources"""
        self.active_sessions.clear()
        self.is_initialized = False
        logger.info("ADK Tutor Service cleaned up")


# Singleton instance
adk_tutor_service = ADKTutorService()
