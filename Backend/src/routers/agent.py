"""
ADK Agent Router - Exposes the ADK-based Arabic Tutor Agent
Uses Google Agent Development Kit (ADK) for multi-step tutoring
"""

import logging
from typing import Optional, List

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel

from services.adk_agent import adk_tutor_service

logger = logging.getLogger(__name__)

router = APIRouter()


class AgentMessageRequest(BaseModel):
    message: str
    session_id: Optional[str] = None
    context: Optional[str] = None


class AgentMessageResponse(BaseModel):
    text: str
    tool_calls: list = []
    session_id: str


class TeachLessonRequest(BaseModel):
    session_id: str
    category: str
    words: List[dict]


class EvaluateRequest(BaseModel):
    session_id: str
    expected_word: str
    student_said: str


@router.post("/message", response_model=AgentMessageResponse)
async def agent_message(
    request: AgentMessageRequest,
    authorization: Optional[str] = Header(None)
):
    """
    Send a message to the ADK Arabic Tutor Agent.
    The agent will use its tools (teach_word, evaluate_pronunciation, etc.)
    to handle the tutoring task.
    """
    try:
        session_id = request.session_id or "default"
        
        result = await adk_tutor_service.process_message(
            session_id=session_id,
            message=request.message,
            context=request.context
        )
        
        return AgentMessageResponse(
            text=result["text"],
            tool_calls=result.get("tool_calls", []),
            session_id=result["session_id"]
        )
        
    except Exception as e:
        logger.error(f"Agent message error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/teach")
async def teach_lesson(
    request: TeachLessonRequest,
    authorization: Optional[str] = Header(None)
):
    """Use the ADK agent to teach a lesson with specific words"""
    try:
        result = await adk_tutor_service.teach_lesson(
            session_id=request.session_id,
            category=request.category,
            words=request.words
        )
        
        return result
        
    except Exception as e:
        logger.error(f"Teach lesson error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/evaluate")
async def evaluate_pronunciation(
    request: EvaluateRequest,
    authorization: Optional[str] = Header(None)
):
    """Use the ADK agent to evaluate student pronunciation"""
    try:
        result = await adk_tutor_service.evaluate_student(
            session_id=request.session_id,
            expected_word=request.expected_word,
            student_said=request.student_said
        )
        
        return result
        
    except Exception as e:
        logger.error(f"Evaluate error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/info")
async def agent_info():
    """Get information about the ADK agent"""
    return {
        "name": "EL-Modras Tutor Agent",
        "framework": "Google ADK (Agent Development Kit)",
        "model": "gemini-2.5-flash",
        "tools": [
            "teach_word",
            "evaluate_pronunciation",
            "generate_story_scene",
            "recognize_object_in_image",
            "track_progress",
            "get_lesson_content"
        ],
        "description": "AI Arabic Language Tutor for Kids - built with Google ADK"
    }
