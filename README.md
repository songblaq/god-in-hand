# 🤲 God in Hand

**Turn your smartphone into an autonomous AI agent machine — entirely on-device.**

[한국어 README](README.ko.md)

God in Hand integrates **local LLM model serving + AI agent runtime + skill/plugin system** on a smartphone, so your phone can think, decide, and act autonomously — without cloud APIs.

## What Makes This Different

Existing projects like OpenClaw-on-Android run the agent locally but call cloud APIs for LLM inference. **God in Hand runs everything on-device**: Gemma 4, Qwen3, and other models serve locally via Ollama, while OpenClaw provides the agent runtime and skill system.

## Architecture

```
┌─────────────────────────────────────────────────┐
│       God in Hand Hub (Web Dashboard)           │
│  Device monitoring · Query routing · Skills     │
└──────────────┬──────────────────────────────────┘
               │
┌──────────────┴──────────────────────────────────┐
│  Layer 1: Model Serving                         │
│  Android: Ollama / llama.cpp (localhost:11434)   │
│  iOS: ExecuTorch / Off Grid (localhost:8005)     │
│  Fallback: Cloud API (Claude / Gemini)           │
└──────────────┬──────────────────────────────────┘
               │
┌──────────────┴──────────────────────────────────┐
│  Layer 2: Agent Runtime — OpenClaw              │
│  Gateway · Task Flows · Multi-channel           │
│  WhatsApp · Telegram · Slack · Discord · SMS    │
└──────────────┬──────────────────────────────────┘
               │
┌──────────────┴──────────────────────────────────┐
│  Layer 3: Skills & Plugins                      │
│  Browser · Files · Cron · Camera · GPS          │
│  Termux:API · ClawHub · Custom K-Skills         │
└─────────────────────────────────────────────────┘
```

## Supported Devices & Models

| Device | RAM | Recommended Role | Primary Model | Router Model |
|--------|-----|-----------------|---------------|-------------|
| Galaxy S21 | 8GB | Worker | Gemma 4 E2B | Qwen3 0.6B |
| Galaxy S26 | 12GB | Hub | Gemma 4 E4B | Qwen3 0.6B |
| Galaxy Z Fold7 | 16GB | Power Node | Gemma 4 E4B / Qwen3.5 35B-A3B | Qwen3 0.6B |
| iPhone 15/16 Pro | 8GB | Remote Node | Qwen3 0.6B~1.7B (ExecuTorch) | — |

### Model Matrix (Q4 Quantization)

| Model | RAM Required | Features | License |
|-------|-------------|----------|---------|
| Gemma 4 E2B | ~1.5GB | Text + Image + Audio + Tool Calling | Apache 2.0 |
| Gemma 4 E4B | ~5GB | Text + Image + Audio + Tool Calling | Apache 2.0 |
| Qwen3 0.6B | ~0.5GB | Text, Think/No-Think | Apache 2.0 |
| Qwen3 4B | ~3GB | Text, 72B-level reasoning | Apache 2.0 |
| Qwen3.5 35B-A3B (MoE) | ~4GB | Text, 32B-level quality, 3B active | Apache 2.0 |

## Quick Start

### One-line Install (Android + Termux)

```bash
# English
curl -sL https://raw.githubusercontent.com/user/god-in-hand/main/install.sh | bash

# Korean / 한국어
curl -sL https://raw.githubusercontent.com/user/god-in-hand/main/install.sh | bash -s -- --lang ko
```

### Manual Install

```bash
# 1. Clone the repo
git clone https://github.com/user/god-in-hand.git
cd god-in-hand

# 2. Run the installer
bash install.sh

# Options:
bash install.sh --dry-run          # Check only, no install
bash install.sh --skip-model       # Install without downloading models
bash install.sh --device-role hub  # Set device role
bash install.sh --engine llamacpp  # Use llama.cpp instead of Ollama
bash install.sh --lang ko          # Force Korean UI
```

### After Installation

```bash
# Chat with your local LLM
ollama run gemma4:e2b

# Start the AI agent
openclaw

# Run diagnostics
openclaw doctor

# Start the hub dashboard
cd ~/.god-in-hand/hub && python -m http.server 8080
# Open http://localhost:8080 in your browser
```

## Project Structure

```
god-in-hand/
├── install.sh              # Main installer (Phase 0-5)
├── lib/
│   ├── detect.sh           # Device & environment detection
│   ├── models.sh           # RAM-based model recommendation
│   ├── health.sh           # Health checks & diagnostics
│   └── i18n.sh             # Internationalization (en/ko)
├── config/
│   ├── devices.json        # Device profiles & roles
│   └── models.json         # Model catalog & specs
├── hub/
│   └── index.html          # Single-file web dashboard
├── docs/
│   ├── ios-setup.md        # iOS connection guide
│   └── troubleshooting.md  # Common issues & fixes
├── README.md               # This file
└── README.ko.md            # Korean README
```

## Multi-Device Setup

God in Hand supports a multi-device mesh where phones collaborate:

1. **Hub** (12GB+ RAM): Runs OpenClaw gateway + primary model. Routes queries.
2. **Worker** (8GB RAM): Dedicated background tasks, lightweight inference.
3. **Power Node** (16GB+ RAM): Complex reasoning and multimodal processing.
4. **Remote Node** (iOS): Connects to Android hub via WiFi.

```bash
# On hub device
bash install.sh --device-role hub

# On worker device
bash install.sh --device-role worker

# Pair devices
openclaw node pair
```

## iOS Support

iOS cannot run Termux, so a dual strategy is used:

1. **Local model only**: ExecuTorch or Off Grid app for lightweight inference
2. **Agent via remote**: Connect to Android hub over WiFi

See [docs/ios-setup.md](docs/ios-setup.md) for detailed instructions.

## Requirements

- **Android 10+** (API 29+)
- **Termux** from F-Droid (NOT Play Store)
- **aarch64** CPU architecture
- **4GB+ RAM** (8GB+ recommended)
- **10GB+ free storage**

## Known Issues & Precautions

- Samsung One UI aggressively kills background apps — disable battery optimization for Termux
- OpenClaw Termux support is community-maintained, not official
- WiFi switching can crash mDNS — restart the gateway after network changes
- Long LLM inference causes thermal throttling — the system includes cooldown logic
- Ollama v0.20+ required for Gemma 4 support

## Contributing

Contributions welcome! Please open an issue or PR.

## License

MIT License. See [LICENSE](LICENSE) for details.

Individual model licenses vary (Apache 2.0, Llama 3.2 License, MIT). Check `config/models.json` for each model's license.
