# EL-Modras (المدرس) - AI Arabic Language Tutor

> Real-time AI-powered Arabic language tutor using Gemini Live API for natural voice conversations and visual vocabulary learning.

![Gemini Live Agent Challenge](https://img.shields.io/badge/Hackathon-Gemini%20Live%20Agent%20Challenge-blue)
![Category](https://img.shields.io/badge/Category-Live%20Agents-green)
![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Cloud%20Run-orange)

## 📖 Overview

EL-Modras ("The Teacher" in Arabic) is a **Live Agent** that breaks the "text box" paradigm by enabling natural, real-time voice conversations for learning Arabic. Using **Gemini Live API**, learners can:

- 🗣️ **Speak naturally** with an AI tutor that handles interruptions gracefully
- 👁️ **Point their camera** at objects to learn Arabic vocabulary visually
- 🎯 **Get instant pronunciation feedback** in real-time
- 📊 **Track progress** with personalized lesson recommendations

## 🎥 Demo Video

[Watch the 4-minute demo video](https://youtube.com/watch?v=YOUR_VIDEO_ID)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (SwiftUI)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  HomeView   │  │ LessonView  │  │    CameraVocabView      │  │
│  │  (MVVM)     │  │  (MVVM)     │  │       (MVVM)            │  │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘  │
│         │                │                     │                 │
│  ┌──────▼────────────────▼─────────────────────▼─────────────┐  │
│  │              Core Services Layer                           │  │
│  │  ┌────────────────┐  ┌────────────────┐                   │  │
│  │  │ AudioService   │  │ GeminiService  │                   │  │
│  │  │ (AVAudioEngine)│  │ (Network)      │                   │  │
│  │  └────────────────┘  └────────────────┘                   │  │
│  └───────────────────────────┬───────────────────────────────┘  │
└──────────────────────────────┼───────────────────────────────────┘
                               │ WebSocket / HTTPS
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Google Cloud Run                              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                 FastAPI Backend (Python)                   │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐ │  │
│  │  │ Session API  │  │  Vision API  │  │ Pronunciation API│ │  │
│  │  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘ │  │
│  │         │                 │                    │           │  │
│  │  ┌──────▼─────────────────▼────────────────────▼─────────┐│  │
│  │  │              Gemini Service (ADK)                      ││  │
│  │  │  • Live API for real-time audio streaming              ││  │
│  │  │  • Vision API for object recognition                   ││  │
│  │  │  • Pronunciation analysis                              ││  │
│  │  └────────────────────────┬───────────────────────────────┘│  │
│  └───────────────────────────┼───────────────────────────────┘  │
└──────────────────────────────┼───────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Google Cloud Services                         │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐ │
│  │   Gemini     │  │  Firestore   │  │   Secret Manager       │ │
│  │  2.0 Flash   │  │  (Progress)  │  │   (API Keys)           │ │
│  └──────────────┘  └──────────────┘  └────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🛠️ Tech Stack

### iOS App
- **SwiftUI** with Clean Architecture (MVVM)
- **AVAudioEngine** for real-time audio capture/playback
- **AVFoundation** for camera integration
- **WebSocket** for bidirectional audio streaming

### Backend
- **Python 3.11** with FastAPI
- **Google GenAI SDK** for Gemini API
- **Google ADK** (Agent Development Kit)
- **Cloud Run** for serverless hosting

### Google Cloud Services
- **Gemini 2.0 Flash** with Live API
- **Cloud Run** for backend hosting
- **Cloud Firestore** for user data
- **Secret Manager** for API keys

## 🚀 Quick Start

### Prerequisites

- Xcode 15+ (for iOS app)
- Python 3.11+
- Google Cloud SDK
- Gemini API key ([Get one here](https://aistudio.google.com/apikey))

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/el-modras.git
cd el-modras
```

### 2. Backend Setup

```bash
cd Backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export GOOGLE_CLOUD_PROJECT=your-project-id
export GEMINI_API_KEY=your-gemini-api-key

# Run locally
python src/main.py
```

The backend will start at `http://localhost:8080`

### 3. iOS App Setup

1. Open `EL-Modras.xcodeproj` in Xcode
2. Update `Core/Network/AppConfig.swift` with your backend URL:
   ```swift
   static var backendURL: String {
       return "http://localhost:8080"  // or your Cloud Run URL
   }
   ```
3. Add your Gemini API key to the scheme environment variables
4. Build and run on a physical device (camera/microphone required)

### 4. Deploy to Google Cloud

```bash
cd Backend

# Setup infrastructure (Firestore, Secret Manager, etc.)
chmod +x scripts/setup-infrastructure.sh
./scripts/setup-infrastructure.sh

# Deploy to Cloud Run
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

## 📁 Project Structure

```
EL-Modras/
├── EL-Modras/                    # iOS App
│   ├── Domain/                   # Business logic layer
│   │   ├── Entities/             # Data models
│   │   ├── UseCases/             # Application use cases
│   │   └── Repositories/         # Repository interfaces
│   ├── Data/                     # Data layer
│   │   ├── Repositories/         # Repository implementations
│   │   └── DataSources/          # Remote & local data sources
│   ├── Presentation/             # UI layer (MVVM)
│   │   ├── Home/                 # Home screen
│   │   ├── Lesson/               # Voice lesson screen
│   │   ├── CameraVocab/          # Camera vocabulary screen
│   │   └── Progress/             # Progress tracking screen
│   └── Core/                     # Core services
│       ├── Network/              # API services
│       ├── Audio/                # Audio processing
│       └── DI/                   # Dependency injection
├── Backend/                      # Python backend
│   ├── src/
│   │   ├── main.py               # FastAPI application
│   │   ├── config.py             # Configuration
│   │   ├── routers/              # API endpoints
│   │   └── services/             # Business services
│   ├── scripts/                  # Deployment scripts
│   ├── Dockerfile
│   └── requirements.txt
└── README.md
```

## ✨ Features

### 🗣️ Real-Time Voice Conversations
- Natural Arabic tutoring with Gemini Live API
- Handles interruptions (barge-in) gracefully
- Low-latency audio streaming via WebSocket

### 👁️ Visual Vocabulary Learning
- Point camera at any object
- Gemini Vision identifies and teaches Arabic word
- Includes pronunciation, transliteration, and example sentences

### 📊 Progress Tracking
- Words learned, lessons completed, practice time
- Daily streaks and achievements
- Category-based progress visualization

### 🎯 Pronunciation Feedback
- Real-time pronunciation scoring
- Constructive feedback and suggestions
- Practice specific words until mastered

## 🔧 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/session/start` | POST | Start Gemini Live session |
| `/api/v1/session/{id}/audio` | POST | Send audio message |
| `/api/v1/session/{id}/end` | POST | End session |
| `/api/v1/vision/recognize` | POST | Recognize object from image |
| `/api/v1/pronunciation/analyze` | POST | Analyze pronunciation |
| `/api/v1/chat` | POST | Text chat (fallback) |
| `/ws/{session_id}` | WebSocket | Real-time audio streaming |

## 📱 Screenshots

| Home | Lesson | Camera | Progress |
|------|--------|--------|----------|
| ![Home](screenshots/home.png) | ![Lesson](screenshots/lesson.png) | ![Camera](screenshots/camera.png) | ![Progress](screenshots/progress.png) |

## 🏆 Hackathon Submission

**Category:** Live Agents 🗣️

**Mandatory Tech Used:**
- ✅ Gemini Live API for real-time audio
- ✅ Google GenAI SDK
- ✅ Google ADK (Agent Development Kit)
- ✅ Hosted on Google Cloud Run

**Google Cloud Services:**
- Gemini 2.0 Flash (Live API)
- Cloud Run
- Cloud Firestore
- Secret Manager

## 👥 Team

- **Your Name** - Developer

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Built with ❤️ for the Gemini Live Agent Challenge 2026
