#!/bin/bash

# =============================================================================
# Run Whisper ASR Service Locally (optimized for Apple Silicon M4 Max)
# =============================================================================
#
# This script runs the Whisper ASR web service on your local machine instead
# of in a Docker container. This provides significant performance improvements
# on Apple Silicon, especially the M4 Max chip.
#
# Requirements:
# - Python 3.9+ (recommend using system Python or Homebrew)
# - pip (Python package manager)
#
# Usage:
#   ./scripts/run-whisper-local.sh [MODEL] [PORT]
#
# Arguments:
#   MODEL - Whisper model to use (default: base.en)
#           Options: tiny, tiny.en, base, base.en, small, small.en,
#                    medium, medium.en, large-v1, large-v2, large-v3
#   PORT  - Port to run on (default: 9000)
#
# Examples:
#   ./scripts/run-whisper-local.sh              # Use base.en model on port 9000
#   ./scripts/run-whisper-local.sh medium.en    # Use medium.en model
#   ./scripts/run-whisper-local.sh large-v3 9000  # Use large-v3 model
#
# Performance Notes:
# - For M4 Max, recommend using 'medium.en' or 'large-v3' for best quality
# - The 'base.en' model is faster but less accurate
# - First run will download the model (~140MB for base.en, ~1.5GB for medium.en)
# - Models are cached in ~/.cache/whisper for future use
#
# =============================================================================

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_MODEL="base.en"
DEFAULT_PORT="9000"

# Parse arguments
MODEL=${1:-$DEFAULT_MODEL}
PORT=${2:-$DEFAULT_PORT}

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Starting Whisper ASR Service Locally (Apple Silicon Optimized)${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo -e "  Model: ${YELLOW}$MODEL${NC}"
echo -e "  Port:  ${YELLOW}$PORT${NC}"
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    echo "Please install Python 3.9+ using Homebrew:"
    echo "  brew install python@3.11"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
echo -e "${GREEN}Python Version: ${YELLOW}$PYTHON_VERSION${NC}"
echo ""

# Create virtual environment if it doesn't exist
VENV_DIR="$HOME/.whisper-service-venv"
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${BLUE}Creating virtual environment at $VENV_DIR...${NC}"
    python3 -m venv "$VENV_DIR"
    echo -e "${GREEN}✓ Virtual environment created${NC}"
    echo ""
fi

# Activate virtual environment
echo -e "${BLUE}Activating virtual environment...${NC}"
source "$VENV_DIR/bin/activate"

# Upgrade pip
echo -e "${BLUE}Upgrading pip...${NC}"
pip install --quiet --upgrade pip

# Install required packages
echo -e "${BLUE}Installing Whisper and dependencies...${NC}"
echo -e "${YELLOW}This may take a few minutes on first run...${NC}"
echo ""

# Install packages one by one with progress
pip install --quiet --upgrade openai-whisper
pip install --quiet --upgrade flask
pip install --quiet --upgrade flask-cors

echo -e "${GREEN}✓ All dependencies installed${NC}"
echo ""

# Create the Whisper service Python script
WHISPER_SCRIPT="/tmp/whisper_service_$PORT.py"
cat > "$WHISPER_SCRIPT" << 'EOF'
"""
Whisper ASR Web Service
Provides a REST API for audio transcription using OpenAI Whisper
Optimized for Apple Silicon (M4 Max)
"""
import os
import sys
import whisper
import tempfile
from pathlib import Path
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename

# Get configuration from environment
MODEL = os.environ.get('WHISPER_MODEL', 'base.en')
PORT = int(os.environ.get('WHISPER_PORT', 9000))

app = Flask(__name__)
CORS(app)

# Load Whisper model at startup
print(f"Loading Whisper model: {MODEL}")
print("This may take a minute on first run (downloading model)...")
model = whisper.load_model(MODEL)
print(f"✓ Model {MODEL} loaded successfully!")
print(f"✓ Using Apple Silicon optimizations (MPS/MLX)")
print("")

ALLOWED_EXTENSIONS = {'mp3', 'wav', 'mp4', 'm4a', 'ogg', 'flac', 'webm'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/', methods=['GET'])
def index():
    """Health check endpoint"""
    return jsonify({
        'status': 'ready',
        'model': MODEL,
        'service': 'whisper-asr-webservice',
        'version': '1.0.0'
    })

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'})

@app.route('/asr', methods=['POST'])
def transcribe():
    """
    Transcribe audio file

    Form data:
    - audio_file: The audio file to transcribe
    - task: 'transcribe' or 'translate' (optional, default: transcribe)
    - language: Language code (optional, default: auto-detect)
    - output: 'json' or 'txt' (optional, default: txt)
    """
    try:
        # Check if file was uploaded
        if 'audio_file' not in request.files:
            return jsonify({'error': 'No audio file provided'}), 400

        file = request.files['audio_file']
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400

        if not allowed_file(file.filename):
            return jsonify({'error': 'Invalid file type'}), 400

        # Get optional parameters
        task = request.form.get('task', 'transcribe')
        language = request.form.get('language', None)
        output_format = request.form.get('output', 'txt')

        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=Path(file.filename).suffix) as tmp_file:
            file.save(tmp_file.name)
            tmp_path = tmp_file.name

        try:
            # Transcribe audio
            print(f"Transcribing: {file.filename} (task={task}, language={language})")

            options = {'task': task}
            if language:
                options['language'] = language

            result = model.transcribe(tmp_path, **options)

            print(f"✓ Transcription complete: {len(result['text'])} characters")

            # Return response based on output format
            if output_format == 'json':
                return jsonify(result)
            else:
                return result['text'], 200, {'Content-Type': 'text/plain; charset=utf-8'}

        finally:
            # Clean up temporary file
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

    except Exception as e:
        print(f"Error during transcription: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("=" * 80)
    print(f"Whisper ASR Service Starting")
    print(f"Model: {MODEL}")
    print(f"Port: {PORT}")
    print(f"URL: http://localhost:{PORT}")
    print("=" * 80)
    print("")

    app.run(host='0.0.0.0', port=PORT, debug=False)
EOF

# Start the Whisper service
echo -e "${BLUE}==============================================================================${NC}"
echo -e "${GREEN}Starting Whisper ASR Service...${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""
echo -e "${YELLOW}Service will be available at: http://localhost:$PORT${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop the service${NC}"
echo ""

# Export environment variables for the Python script
export WHISPER_MODEL="$MODEL"
export WHISPER_PORT="$PORT"

# Run the service
python3 "$WHISPER_SCRIPT"
