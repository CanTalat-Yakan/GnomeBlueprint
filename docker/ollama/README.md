# Ollama + Open WebUI

Local LLM inference with Ollama and a web-based chat interface via Open WebUI.

## Addresses

| Service | URL |
|---|---|
| **Open WebUI** | http://localhost:3000 |
| **Ollama API** | http://localhost:11434 |

On first launch, Open WebUI will ask you to create an admin account.

## Quick Commands

```bash
cd ~/ollama

# Start (detached)
docker compose up -d

# Stop
docker compose down

# Update to latest version
docker compose pull
docker compose up -d

# Pull a model (e.g. llama3)
docker exec ollama ollama pull llama3

# List downloaded models
docker exec ollama ollama list
```

## Data

- Ollama models are stored in `./ollama-data/`
- Open WebUI data (users, chat history) is stored in `./open-webui-data/`

## GPU Support

The compose file requests all NVIDIA GPUs by default. If you don't have an NVIDIA GPU, remove the `deploy.resources` section from the `ollama` service.

