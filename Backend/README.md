# EL-Modras Backend

Arabic Language Tutor powered by Gemini Live API.

## Requirements

- Python 3.11+
- Google Cloud SDK
- Gemini API access

## Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export GOOGLE_CLOUD_PROJECT=your-project-id
export GEMINI_API_KEY=your-api-key

# Run locally
python src/main.py
```

## Deployment

```bash
# Deploy to Cloud Run
./scripts/deploy.sh
```

## API Endpoints

- `POST /api/v1/session/start` - Start a new Gemini Live session
- `POST /api/v1/session/{id}/audio` - Send audio message
- `POST /api/v1/session/{id}/end` - End session
- `POST /api/v1/vision/recognize` - Recognize object from image
- `POST /api/v1/pronunciation/analyze` - Analyze pronunciation
- `POST /api/v1/chat` - Text-based chat (fallback)
- `WS /ws/{session_id}` - WebSocket for real-time audio streaming
