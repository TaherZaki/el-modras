"""
Vision Router - Handles object recognition with Gemini Vision
"""

import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, UploadFile, File, Header
from pydantic import BaseModel

from services.gemini_service import gemini_service

logger = logging.getLogger(__name__)
router = APIRouter()


class VisionResponse(BaseModel):
    english_name: str
    arabic_name: str
    transliteration: str
    confidence: float
    description: Optional[str] = None


@router.post("/recognize", response_model=VisionResponse)
async def recognize_object(
    image: UploadFile = File(...),
    authorization: Optional[str] = Header(None)
):
    """Recognize an object in an image and return Arabic vocabulary"""
    try:
        # Validate file type
        if not image.content_type or not image.content_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="File must be an image")
        
        # Read image data
        image_data = await image.read()
        
        # Validate file size (max 10MB)
        if len(image_data) > 10 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="Image too large (max 10MB)")
        
        # Process with Gemini Vision
        result = await gemini_service.recognize_object(image_data)
        
        return VisionResponse(
            english_name=result["english_name"],
            arabic_name=result["arabic_name"],
            transliteration=result["transliteration"],
            confidence=result["confidence"],
            description=result.get("description")
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to recognize object: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/batch")
async def recognize_batch(
    images: list[UploadFile] = File(...),
    authorization: Optional[str] = Header(None)
):
    """Recognize objects in multiple images"""
    try:
        results = []
        
        for image in images[:5]:  # Limit to 5 images
            if image.content_type and image.content_type.startswith("image/"):
                image_data = await image.read()
                result = await gemini_service.recognize_object(image_data)
                results.append(result)
        
        return {"results": results, "count": len(results)}
        
    except Exception as e:
        logger.error(f"Failed to process batch: {e}")
        raise HTTPException(status_code=500, detail=str(e))
