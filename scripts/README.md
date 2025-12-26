# Local Whisper Service

This directory contains scripts for running the Whisper ASR service locally on your machine.

## Running Whisper Locally (Apple Silicon Optimized)

For development on Apple Silicon (M1/M2/M3/M4), running Whisper locally provides **significantly better performance** than using a Docker container.

### Quick Start

```bash
./scripts/run-whisper-local.sh
```

This will:
1. Create a Python virtual environment at `~/.whisper-service-venv` (first run only)
2. Install Whisper and dependencies (first run only)
3. Download the model (first run only, ~140MB for base.en model)
4. Start the Whisper service on port 9000

### Usage

```bash
./scripts/run-whisper-local.sh [MODEL] [PORT]
```

**Arguments:**
- `MODEL` - Whisper model to use (default: `base.en`)
- `PORT` - Port to run on (default: `9000`)

**Available Models:**

| Model | Size | English-only | Best for | Recommended for M4 Max |
|-------|------|--------------|----------|------------------------|
| `tiny` | ~75 MB | No | Speed | - |
| `tiny.en` | ~75 MB | Yes | Speed | - |
| `base` | ~140 MB | No | Balanced | - |
| `base.en` | ~140 MB | Yes | Balanced | ✓ (Default) |
| `small` | ~480 MB | No | Better accuracy | - |
| `small.en` | ~480 MB | Yes | Better accuracy | ✓ |
| `medium` | ~1.5 GB | No | High accuracy | - |
| `medium.en` | ~1.5 GB | Yes | High accuracy | ✓ (Recommended) |
| `large-v1` | ~3 GB | No | Best accuracy | - |
| `large-v2` | ~3 GB | No | Best accuracy | ✓ |
| `large-v3` | ~3 GB | No | Best accuracy | ✓ (Best Quality) |

### Examples

```bash
# Use default model (base.en) on port 9000
./scripts/run-whisper-local.sh

# Use medium.en model for better accuracy
./scripts/run-whisper-local.sh medium.en

# Use large-v3 model for best quality on M4 Max
./scripts/run-whisper-local.sh large-v3

# Use custom port
./scripts/run-whisper-local.sh base.en 9001
```

### Performance Notes

**For M4 Max:**
- **Recommended:** `medium.en` or `large-v3` for best quality
- The M4 Max can handle larger models with excellent speed
- First transcription will be slower (model loading)
- Subsequent transcriptions are very fast

**Storage:**
- Models are cached in `~/.cache/whisper`
- Virtual environment is in `~/.whisper-service-venv`

### Testing the Service

```bash
# Check if service is running
curl http://localhost:9000/

# Transcribe an audio file
curl -X POST -F "audio_file=@test.mp3" -F "task=transcribe" -F "output=txt" http://localhost:9000/asr

# Get JSON output with segments
curl -X POST -F "audio_file=@test.mp3" -F "output=json" http://localhost:9000/asr
```

### Troubleshooting

**Issue: "Python 3 is not installed"**
```bash
# Install Python via Homebrew
brew install python@3.11
```

**Issue: Service won't start**
```bash
# Check if port 9000 is already in use
lsof -i :9000

# Kill existing process
kill -9 <PID>

# Or use a different port
./scripts/run-whisper-local.sh base.en 9001
```

**Issue: Model download fails**
- Check your internet connection
- The models are downloaded from Hugging Face
- First run requires downloading the model file

**Issue: Containers can't connect to local service**
- Make sure Docker Desktop is running
- The containers use `host.docker.internal:9000` to connect
- This is configured in `docker-compose.yml` and `.env`

### Stopping the Service

Press `Ctrl+C` in the terminal where the script is running.

### Uninstalling

```bash
# Remove virtual environment
rm -rf ~/.whisper-service-venv

# Remove cached models
rm -rf ~/.cache/whisper
```
