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
    
    # Gemini API
    gemini_api_key: str = os.getenv("GEMINI_API_KEY", "")
    gemini_model: str = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    
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
