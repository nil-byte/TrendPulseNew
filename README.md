# TrendPulse

Multi-source sentiment analysis system. Input a keyword, automatically collect data from Reddit, YouTube, and X (Twitter), then generate an AI-powered sentiment analysis report.

## Architecture

- **Backend**: Python 3.10+ / FastAPI / SQLite
- **Frontend**: Flutter 3.x / Material Design 3 / Riverpod
- **AI**: OpenAI SDK compatible LLM API

## Quick Start

### Backend

```bash
cd backend
pip install -e ".[dev]"
cp .env.example .env  # Fill in your API keys
uvicorn src.main:app --reload
```

### Frontend

```bash
cd app
flutter pub get
flutter run
```

## Project Structure

```
TrendPulseNew/
├── backend/          # Python backend (FastAPI)
│   ├── src/          # Source code
│   └── tests/        # Tests
├── app/              # Flutter frontend
│   └── lib/          # Dart source
└── README.md
```
