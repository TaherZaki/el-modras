"""
Configuration settings for EL-Modras Backend
"""

import os
from typing import List
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings"""
    
    # Environment
    environment: str = os.getenv("ENVIRONMENT", "development")
    
    # Google Cloud
    google_cloud_project: str = os.getenv("GOOGLE_CLOUD_PROJECT", "el-modras")
    
    # Gemini API (using new google-genai SDK)
    gemini_api_key: str = os.getenv("GEMINI_API_KEY", "")
    gemini_model: str = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    gemini_live_model: str = os.getenv("GEMINI_LIVE_MODEL", "gemini-2.0-flash-live-001")
    gemini_image_model: str = os.getenv("GEMINI_IMAGE_MODEL", "gemini-2.0-flash-exp")
    gemini_tts_model: str = os.getenv("GEMINI_TTS_MODEL", "gemini-2.5-flash-preview-tts")
    
    # Server
    host: str = os.getenv("HOST", "0.0.0.0")
    port: int = int(os.getenv("PORT", 8080))
    
    # CORS
    allowed_origins: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "https://*.run.app",
        "*"  # For development - restrict in production
    ]
    
    # Session
    session_timeout_minutes: int = 30
    max_audio_size_mb: int = 10
    
    # Firestore
    firestore_collection_users: str = "users"
    firestore_collection_sessions: str = "sessions"
    firestore_collection_progress: str = "progress"
    
    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()
