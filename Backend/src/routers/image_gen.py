"""
Image Generation Router - Generates illustrations for interactive stories
Uses Gemini's native image generation for interleaved text+image output
"""

import logging
from typing import Optional

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel

from services.gemini_service import gemini_service

logger = logging.getLogger(__name__)

router = APIRouter()


class ImageGenerateRequest(BaseModel):
    prompt: str
    scene_context: Optional[str] = None
    style: str = "cartoon"  # cartoon, watercolor, flat


class ImageGenerateResponse(BaseModel):
    image_base64: Optional[str] = None
    mime_type: str = "image/png"
    success: bool
    error: Optional[str] = None


class StoryIllustrationRequest(BaseModel):
    scene_narration: str
    characters: str
    setting: str
    vocabulary_word: Optional[str] = None


class StoryIllustrationResponse(BaseModel):
    image_base64: Optional[str] = None
    mime_type: str = "image/png"
    narration: Optional[str] = None
    success: bool


@router.post("/generate", response_model=ImageGenerateResponse)
async def generate_image(
    request: ImageGenerateRequest,
    authorization: Optional[str] = Header(None)
):
    """
    Generate an image using Gemini's native image generation.
    This demonstrates Gemini's interleaved/mixed output capabilities.
    """
    try:
        # Build full prompt with style
        style_map = {
            "cartoon": "colorful cartoon illustration, child-friendly, bright colors, simple shapes",
            "watercolor": "soft watercolor painting style, gentle colors, dreamy",
            "flat": "flat design illustration, minimal, modern, clean shapes"
        }
        
        style_desc = style_map.get(request.style, style_map["cartoon"])
        
        full_prompt = request.prompt
        if request.scene_context:
            full_prompt = f"{request.scene_context}\n\n{request.prompt}"
        
        result = await gemini_service.generate_story_image(full_prompt)
        
        if result.get("success"):
            return ImageGenerateResponse(
                image_base64=result["image_base64"],
                mime_type=result.get("mime_type", "image/png"),
                success=True
            )
        else:
            return ImageGenerateResponse(
                success=False,
                error=result.get("error", "Image generation failed")
            )
        
    except Exception as e:
        logger.error(f"Image generation error: {e}")
        return ImageGenerateResponse(
            success=False,
            error=str(e)
        )


@router.post("/story-illustration", response_model=StoryIllustrationResponse)
async def generate_story_illustration(
    request: StoryIllustrationRequest,
    authorization: Optional[str] = Header(None)
):
    """
    Generate an illustration for an interactive story scene.
    Uses Gemini's interleaved output to create both narration and illustration.
    """
    try:
        prompt = f"""A children's storybook illustration:
Setting: {request.setting}
Characters: {request.characters}
Scene: {request.scene_narration}
{"Vocabulary word highlighted: " + request.vocabulary_word if request.vocabulary_word else ""}

Style: Bright, colorful cartoon for children aged 4-8. Friendly characters with big eyes.
No text or words in the image."""

        result = await gemini_service.generate_story_image(prompt)
        
        return StoryIllustrationResponse(
            image_base64=result.get("image_base64"),
            mime_type=result.get("mime_type", "image/png"),
            narration=request.scene_narration,
            success=result.get("success", False)
        )
        
    except Exception as e:
        logger.error(f"Story illustration error: {e}")
        return StoryIllustrationResponse(
            success=False
        )
