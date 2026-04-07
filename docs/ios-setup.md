# iOS Setup Guide

[한국어](#한국어-가이드) | English

Since iOS doesn't support Termux, God in Hand uses a dual strategy for iPhones.

## Strategy 1: Local Model Serving Only

Run a lightweight model directly on the iPhone for basic inference.

### Option A: ExecuTorch (Build Required)

ExecuTorch is Meta's native ML runtime that supports Qwen3 and other models on iOS.

```
Performance benchmark:
  Qwen3 0.6B → ~40 tok/s on iPhone 15 Pro
  Qwen3 1.7B → ~15 tok/s on iPhone 15 Pro
```

**Setup:**

1. Install Xcode 15+ and Java 17
2. Clone ExecuTorch:
   ```bash
   git clone https://github.com/pytorch/executorch.git
   cd executorch
   ```
3. Export the model:
   ```bash
   python -m examples.models.llama.export_llama \
     --model qwen3-0.6b \
     --checkpoint path/to/qwen3-0.6b \
     --params path/to/params.json \
     -kv --use_sdpa_with_kv_cache \
     -d fp32 --xnnpack
   ```
4. Build the iOS app:
   ```bash
   cd examples/demo-apps/apple_ios/LLaMA
   pod install
   open LLaMA.xcworkspace
   ```
5. Deploy to your iPhone via Xcode

### Option B: Off Grid App (App Store)

Off Grid is a cross-platform app that loads GGUF models directly on iOS.

1. Download **Off Grid** from the App Store
2. Import a GGUF model file (e.g., Qwen3 0.6B Q4)
3. The app exposes a local API at `http://localhost:8005`

**Notes:**
- iOS memory management is aggressive — models may be unloaded
- 8GB iPhones can run 0.6B-1.7B models comfortably
- Larger models (3B+) may cause out-of-memory crashes

### Option C: Google AI Edge Gallery

Google's official app for testing Gemma 4 models on mobile.

1. Download **AI Edge Gallery** from the App Store (available April 2026+)
2. Select Gemma 4 E2B from the model list
3. The app includes built-in Agent Skills

## Strategy 2: Remote Agent Connection

Connect your iPhone to the Android hub running OpenClaw.

### Prerequisites
- Android hub device running God in Hand (install.sh completed)
- Both devices on the same WiFi network

### Option A: Web Dashboard (Easiest)

1. Find your Android hub's IP:
   ```bash
   # On Android hub, in Termux:
   ip route get 1.1.1.1 | awk '{print $7}'
   ```
2. On iPhone, open Safari: `http://[ANDROID_IP]:3000`
3. You now have full access to the OpenClaw dashboard

### Option B: SSH Tunnel

For a more secure connection:

1. Install an SSH client on iOS (e.g., Termius, Blink Shell)
2. Set up SSH on the Android hub:
   ```bash
   # In Termux on Android:
   pkg install openssh
   sshd
   # Note the port (default: 8022)
   ```
3. Connect from iPhone:
   ```
   Host: [ANDROID_IP]
   Port: 8022
   User: (your termux username)
   ```
4. Set up port forwarding:
   ```
   Local: 3000 → localhost:3000
   Local: 11434 → localhost:11434
   ```
5. Access dashboard at `http://localhost:3000` on iPhone

### Option C: Messaging Channel

Use the same OpenClaw agent through messaging apps:

1. Configure a channel on the Android hub:
   ```bash
   # In Termux:
   openclaw channel add telegram
   # or: openclaw channel add whatsapp
   ```
2. On iPhone, message the bot through Telegram/WhatsApp
3. Same agent, same skills, different interface

## Strategy 3: Apple Shortcuts Integration (Future)

Connect iOS native automation to OpenClaw via webhooks:

```
Apple Shortcut → HTTP Request → http://[ANDROID_IP]:3000/api/v1/message
```

This enables:
- Siri → OpenClaw voice commands
- Shortcut automations triggering OpenClaw tasks
- iOS Focus modes triggering different agent behaviors

## Recommended Configuration

| iPhone Model | Local Model | Remote Strategy |
|-------------|------------|-----------------|
| iPhone 15 Pro (8GB) | Qwen3 0.6B (ExecuTorch) | Web Dashboard |
| iPhone 16 Pro (8GB) | Qwen3 1.7B (ExecuTorch) | Web Dashboard |
| Older iPhones (<6GB) | Not recommended | Remote only |

---

# 한국어 가이드

iOS에서는 Termux를 지원하지 않으므로, 이중 전략을 사용합니다.

## 전략 1: 로컬 모델 서빙만

iPhone에서 직접 경량 모델을 실행합니다.

- **ExecuTorch**: Meta의 네이티브 ML 런타임. Qwen3 0.6B이 iPhone 15 Pro에서 ~40 tok/s 달성.
- **Off Grid 앱**: App Store에서 다운로드. GGUF 모델 직접 로드 가능.
- **AI Edge Gallery**: Google의 Gemma 4 공식 테스트 앱 (2026.4+ 출시).

## 전략 2: 리모트 에이전트 연결

iPhone을 Android 허브에 연결합니다.

1. **웹 대시보드**: Safari에서 `http://[안드로이드IP]:3000` 접속
2. **SSH 터널**: Termius 등으로 보안 연결
3. **메시징 채널**: Telegram/WhatsApp으로 같은 에이전트 접근

## 전략 3: Apple Shortcuts 연동 (향후)

```
Apple Shortcut → HTTP 요청 → http://[안드로이드IP]:3000/api/v1/message
```

Siri 음성 명령, Shortcut 자동화 등과 연동 가능.
