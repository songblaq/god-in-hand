# 🤲 손 안의 신 (God in Hand)

**스마트폰을 자율 AI 에이전트 머신으로 만드세요 — 완전히 온디바이스로.**

[English README](README.md)

손 안의 신은 스마트폰 위에서 **로컬 LLM 모델 서빙 + AI 에이전트 런타임 + 스킬/플러그인 시스템**을 통합하여, 폰이 스스로 판단하고 조작하는 자율 에이전트 머신을 만드는 프로젝트입니다.

## 핵심 차별점

기존 OpenClaw-on-Android 프로젝트들은 에이전트만 로컬이고 LLM은 클라우드 API를 사용합니다. **손 안의 신은 모든 것을 온디바이스로 실행합니다**: Gemma 4, Qwen3 등의 모델을 Ollama로 로컬 서빙하고, OpenClaw가 에이전트 런타임과 스킬 시스템을 제공합니다.

## 아키텍처

```
┌─────────────────────────────────────────────────┐
│       God in Hand 허브 (웹 대시보드)              │
│  디바이스 모니터링 · 쿼리 라우팅 · 스킬 관리       │
└──────────────┬──────────────────────────────────┘
               │
┌──────────────┴──────────────────────────────────┐
│  Layer 1: 모델 서빙                              │
│  Android: Ollama / llama.cpp (localhost:11434)   │
│  iOS: ExecuTorch / Off Grid (localhost:8005)     │
│  폴백: Cloud API (Claude / Gemini)               │
└──────────────┬──────────────────────────────────┘
               │
┌──────────────┴──────────────────────────────────┐
│  Layer 2: 에이전트 런타임 — OpenClaw              │
│  게이트웨이 · Task Flows · 멀티채널              │
│  WhatsApp · Telegram · Slack · Discord · SMS    │
└──────────────┬──────────────────────────────────┘
               │
┌──────────────┴──────────────────────────────────┐
│  Layer 3: 스킬 & 플러그인                        │
│  브라우저 · 파일 · 크론 · 카메라 · GPS            │
│  Termux:API · ClawHub · 커스텀 K-Skills          │
└─────────────────────────────────────────────────┘
```

## 지원 디바이스 & 모델

| 디바이스 | RAM | 추천 역할 | 메인 모델 | 라우터 모델 |
|---------|-----|----------|----------|-----------|
| Galaxy S21 | 8GB | 워커 | Gemma 4 E2B | Qwen3 0.6B |
| Galaxy S26 | 12GB | 허브 | Gemma 4 E4B | Qwen3 0.6B |
| Galaxy Z Fold7 | 16GB | 파워 노드 | Gemma 4 E4B / Qwen3.5 35B-A3B | Qwen3 0.6B |
| iPhone 15/16 Pro | 8GB | 리모트 노드 | Qwen3 0.6B~1.7B (ExecuTorch) | — |

### 모델 매트릭스 (Q4 양자화 기준)

| 모델 | 필요 RAM | 특징 | 라이선스 |
|-----|---------|------|---------|
| Gemma 4 E2B | ~1.5GB | 텍스트 + 이미지 + 오디오 + Tool Calling | Apache 2.0 |
| Gemma 4 E4B | ~5GB | 텍스트 + 이미지 + 오디오 + Tool Calling | Apache 2.0 |
| Qwen3 0.6B | ~0.5GB | 텍스트, Think/No-Think 모드 | Apache 2.0 |
| Qwen3 4B | ~3GB | 텍스트, 72B급 추론 성능 | Apache 2.0 |
| Qwen3.5 35B-A3B (MoE) | ~4GB | 텍스트, 32B급 품질, 3B만 활성화 | Apache 2.0 |

## 빠른 시작

### 원라인 설치 (Android + Termux)

```bash
# 한국어
curl -sL https://raw.githubusercontent.com/songblaq/god-in-hand/main/install.sh | bash -s -- --lang ko

# English
curl -sL https://raw.githubusercontent.com/songblaq/god-in-hand/main/install.sh | bash
```

### 수동 설치

```bash
# 1. 저장소 클론
git clone https://github.com/songblaq/god-in-hand.git
cd god-in-hand

# 2. 설치 스크립트 실행
bash install.sh --lang ko

# 옵션:
bash install.sh --dry-run          # 점검만, 실제 설치 안 함
bash install.sh --skip-model       # 모델 다운로드 나중에
bash install.sh --device-role hub  # 디바이스 역할 지정
bash install.sh --engine llamacpp  # Ollama 대신 llama.cpp 사용
```

### 설치 후

```bash
# 로컬 LLM과 대화
ollama run gemma4:e2b

# AI 에이전트 시작
openclaw

# 진단 실행
openclaw doctor

# 허브 대시보드 시작
cd ~/.god-in-hand/hub && python -m http.server 8080
# 브라우저에서 http://localhost:8080 열기
```

## 멀티디바이스 구성

손 안의 신은 여러 폰이 협력하는 메시 네트워크를 지원합니다:

1. **허브** (12GB+ RAM): OpenClaw 게이트웨이 + 메인 모델. 쿼리 라우팅.
2. **워커** (8GB RAM): 백그라운드 작업 전담, 경량 추론.
3. **파워 노드** (16GB+ RAM): 복잡한 추론, 멀티모달 처리.
4. **리모트 노드** (iOS): WiFi로 Android 허브에 연결.

## iOS 지원

iOS에서는 Termux를 사용할 수 없으므로 이중 전략을 사용합니다:

1. **로컬 모델만**: ExecuTorch 또는 Off Grid 앱으로 경량 추론
2. **에이전트는 리모트**: WiFi로 Android 허브에 연결

자세한 내용은 [docs/ios-setup.md](docs/ios-setup.md)를 참고하세요.

## 요구 사항

- **Android 10+** (API 29+)
- **Termux** — F-Droid에서 설치 (Play Store 버전 사용 불가)
- **aarch64** CPU 아키텍처
- **4GB+ RAM** (8GB+ 권장)
- **10GB+ 여유 저장 공간**

## 주의 사항

- Samsung One UI가 백그라운드 앱을 강제 종료합니다 — Termux 배터리 최적화 해제 필수
- OpenClaw의 Termux 지원은 커뮤니티 유지 관리 (비공식)
- WiFi 전환 시 mDNS가 크래시할 수 있습니다 — 네트워크 변경 후 게이트웨이 재시작
- 장시간 LLM 추론 시 발열로 인한 쓰로틀링 발생 — 쿨다운 로직 내장
- Gemma 4 지원을 위해 Ollama v0.20+ 필요

## 기여

기여를 환영합니다! 이슈나 PR을 열어주세요.

## 라이선스

MIT License. 개별 모델의 라이선스는 다릅니다 (Apache 2.0, Llama 3.2 License, MIT). 각 모델의 라이선스는 `config/models.json`을 참고하세요.
