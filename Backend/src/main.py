"""
EL-Modras Backend - Main Application
Arabic Language Tutor powered by Gemini Live API & ADK
Uses the new google-genai SDK and Google ADK (Agent Development Kit)
"""

import os
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from routers import session, vision, pronunciation, chat, tts, live
from routers import agent as agent_router
from routers import image_gen
from services.gemini_service import GeminiService
from services.gemini_live_service import gemini_live_service
from services.adk_agent import adk_tutor_service
from services.websocket_manager import WebSocketManager

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize services
gemini_service = GeminiService()
ws_manager = WebSocketManager()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler"""
    logger.info("Starting EL-Modras Backend...")
    logger.info(f"Environment: {settings.environment}")
    logger.info(f"Google Cloud Project: {settings.google_cloud_project}")
    logger.info("SDK: google-genai (new) + Google ADK")
    
    # Initialize all services
    await gemini_service.initialize()
    await gemini_live_service.initialize()
    await adk_tutor_service.initialize()
    
    yield
    
    # Cleanup
    logger.info("Shutting down EL-Modras Backend...")
    await gemini_service.cleanup()
    await gemini_live_service.cleanup()
    await adk_tutor_service.cleanup()


# Create FastAPI app
app = FastAPI(
    title="EL-Modras API",
    description="Arabic Language Tutor powered by Gemini Live API, Google GenAI SDK & ADK",
    version="2.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(session.router, prefix="/api/v1/session", tags=["Session"])
app.include_router(vision.router, prefix="/api/v1/vision", tags=["Vision"])
app.include_router(pronunciation.router, prefix="/api/v1/pronunciation", tags=["Pronunciation"])
app.include_router(chat.router, prefix="/api/v1/chat", tags=["Chat"])
app.include_router(tts.router, prefix="/api/v1/tts", tags=["Text-to-Speech"])
app.include_router(live.router, tags=["Live API"])
app.include_router(agent_router.router, prefix="/api/v1/agent", tags=["ADK Agent"])
app.include_router(image_gen.router, prefix="/api/v1/image", tags=["Image Generation"])


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "name": "EL-Modras API",
        "version": "2.0.0",
        "status": "running",
        "description": "Arabic Language Tutor powered by Gemini Live API & ADK",
        "sdk": "google-genai (new GenAI SDK)",
        "frameworks": ["Google ADK (Agent Development Kit)", "Gemini Live API"],
        "google_cloud_services": [
            "Cloud Run",
            "Gemini 2.0 Flash (Live API)",
            "Cloud Firestore",
            "Secret Manager",
            "Cloud Speech-to-Text",
            "Cloud Text-to-Speech",
            "Cloud Storage"
        ]
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "gemini_connected": gemini_service.is_connected,
        "live_api_ready": gemini_live_service.is_initialized,
        "adk_agent_ready": adk_tutor_service.is_initialized,
        "model": settings.gemini_model
    }


@app.websocket("/ws/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    """WebSocket endpoint for real-time audio streaming"""
    await ws_manager.connect(websocket, session_id)
    
    try:
        while True:
            # Receive audio data from client
            data = await websocket.receive_bytes()
            
            # Process with Gemini Live API
            response = await gemini_service.process_audio_stream(session_id, data)
            
            if response:
                # Send response back to client
                await ws_manager.send_audio(session_id, response)
                
    except WebSocketDisconnect:
        ws_manager.disconnect(session_id)
        logger.info(f"WebSocket disconnected: {session_id}")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        ws_manager.disconnect(session_id)


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8080)),
        reload=settings.environment == "development"
    )
