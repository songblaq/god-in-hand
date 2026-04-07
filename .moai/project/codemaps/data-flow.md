# God in Hand — 데이터 흐름

> 설치 라이프사이클, 런타임 요청 흐름, 상태 관리 경로

---

## 1. 설치 라이프사이클

### 전체 흐름도

```
사용자
  │
  ├─[curl|bash]──→ install.sh 스트림 수신
  │                  │
  │                  ├── stdin 재연결 (/dev/tty)
  │                  ├── PIPED_INSTALL=true
  │                  └── bootstrap_repo()
  │                        ├── git clone (git 가용 시)
  │                        └── curl tarball (폴백)
  │
  └─[bash install.sh]──→ install.sh 직접 실행
                           │
                           ↓
                      load_libs()
                    ┌──────────────────────────┐
                    │  source lib/i18n.sh      │
                    │  source lib/detect.sh    │
                    │  source lib/models.sh    │
                    │  source lib/health.sh    │
                    └──────────────────────────┘
                           │
                           ↓
                    ┌─ Phase 0: 사전 점검 ──────────────────────────┐
                    │  detect_termux()     → TERMUX_VERSION        │
                    │  detect_android_version() → ANDROID_API      │
                    │  detect_cpu_arch()   → CPU_ARCH              │
                    │  detect_ram()        → TOTAL_RAM_GB          │
                    │  detect_storage()    → AVAIL_STORAGE_GB      │
                    │  detect_network()    → 연결 여부              │
                    │  detect_device_model(), detect_soc()         │
                    │  detect_battery(), detect_thermal()          │
                    └──────────────────────────────────────────────┘
                           │ [실패 시 사용자 확인 후 계속]
                           ↓
                    ┌─ Phase 1: 기존 설치 감지 ──────────────────────┐
                    │  detect_existing_node()   → NODE_VERSION      │
                    │  detect_existing_openclaw() → OPENCLAW_VERSION│
                    │  detect_existing_ollama() → OLLAMA 존재 여부  │
                    │  detect_existing_models() → EXISTING_MODELS[] │
                    │  detect_stale_locks()     → STALE_LOCKS[]     │
                    │  detect_proot()           → PROOT_INSTALLED   │
                    └──────────────────────────────────────────────┘
                           │
                           ↓
                    ┌─ Phase 2: 권한 및 환경 설정 ───────────────────┐
                    │  termux-setup-storage → ~/storage 디렉토리   │
                    │  termux-wake-lock     → 절전 모드 방지        │
                    │  Termux:Boot 설정 안내                        │
                    └──────────────────────────────────────────────┘
                           │
                           ↓
                    ┌─ Phase 3: 핵심 설치 ───────────────────────────┐
                    │  pkg update && pkg upgrade                    │
                    │  pkg install curl wget git nodejs-lts ...    │
                    │  npm install -g openclaw                     │
                    │                                              │
                    │  [ENGINE=ollama]                             │
                    │    curl ollama.com/install.sh | bash         │
                    │    → ollama serve (백그라운드)                │
                    │    → curl :11434/api/version 검증            │
                    │                                              │
                    │  [ENGINE=llamacpp]                           │
                    │    git clone llama.cpp                       │
                    │    cmake build                               │
                    │    ln -sf llama-server $PREFIX/bin           │
                    │                                              │
                    │  recommend_models(TOTAL_RAM_GB)              │
                    │  → download_model_ollama(tag) / hf(repo)    │
                    │  → openclaw onboard                          │
                    └──────────────────────────────────────────────┘
                           │
                           ↓
                    ┌─ Phase 4: 검증 및 헬스 체크 ──────────────────┐
                    │  openclaw doctor                             │
                    │  check_ollama_status()                       │
                    │  check_openclaw_status()                     │
                    │  check_model_loaded()                        │
                    │  verify_model_inference()                    │
                    └──────────────────────────────────────────────┘
                           │
                           ↓
                    ┌─ Phase 5: Hub 설정 ────────────────────────────┐
                    │  hub/index.html → ~/.god-in-hand/hub/         │
                    │  Hub 서버 시작 (Port 8080)                    │
                    └──────────────────────────────────────────────┘
                           │
                           ↓
                    설치 완료 — 결과 요약 출력
```

---

## 2. 런타임 요청 흐름

### 사용자 쿼리 처리

```
사용자 입력 (텍스트)
  │
  ↓
openclaw CLI / OpenClaw API (Port 3000)
  │  OpenAI 호환 프로토콜 변환
  │  스킬/툴 라우팅 결정
  ↓
Ollama API (Port 11434)
  │  POST /api/chat
  │  { model: "gemma4:e2b", messages: [...] }
  ↓
로컬 LLM 추론 (GGUF 모델)
  │  aarch64 최적화 실행
  │  토큰 스트리밍 응답
  ↓
OpenClaw 응답 처리
  │  스트림 집계, 툴 실행 결과 통합
  ↓
사용자에게 응답 반환
```

### 멀티 모델 라우팅 (Hub 구성)

```
사용자 쿼리
  │
  ↓
OpenClaw 라우터
  ├─[경량/빠른 응답 필요]──→ qwen3:0.6b (Port 11434)  [~40 tok/s]
  │                            트리아지, 분류, 간단 Q&A
  └─[복잡한 추론 필요]────→ gemma4:e4b (Port 11434)
                              멀티모달, 툴 콜링, 복잡 분석
```

---

## 3. Hub 대시보드 데이터 흐름

```
브라우저 (localhost:8080)
  │  hub/index.html 로드 (정적 파일)
  │
  ├── setInterval 폴링 (주기적)
  │     │
  │     ├── fetch("http://localhost:11434/api/version")
  │     │     └── → Ollama 버전, 상태 업데이트
  │     │
  │     ├── fetch("http://localhost:11434/api/tags")
  │     │     └── → 모델 목록, RAM 사용량 카드 업데이트
  │     │
  │     └── fetch("http://localhost:3000/health")
  │           └── → OpenClaw 상태 카드 업데이트
  │
  └── DOM 업데이트 → 사용자에게 실시간 상태 표시
```

---

## 4. 모델 선택 데이터 흐름

```
detect_ram()
  └── TOTAL_RAM_GB = (읽기: /proc/meminfo)

recommend_models(TOTAL_RAM_GB)
  └── 조건 분기 → 모델 ID 목록 반환
        │
        ↓
get_model_info(model_id)
  └── 읽기: config/models.json
        ├── python3 파싱 (우선)
        └── grep 파싱 (폴백)
        → MODEL_NAME, MODEL_OLLAMA_TAG, MODEL_HF_REPO 등 설정

download_model_ollama(tag)
  └── ollama pull {tag}
        └── 네트워크: Ollama 레지스트리 또는 HuggingFace
              → ~/.ollama/models/{tag}/

verify_model_inference(tag)
  └── curl POST /api/generate { model: tag, prompt: "test" }
        └── → 응답 시간 측정, 성공/실패 판정
```

---

## 5. 상태 관리

### 영구 상태 (파일시스템)

| 경로 | 데이터 | 관리 주체 |
|------|--------|-----------|
| `~/.god-in-hand/` | 설치 루트 디렉토리 | install.sh |
| `~/.god-in-hand/logs/install-*.log` | 설치 로그 (타임스탬프 포함) | install.sh |
| `~/.god-in-hand/logs/ollama.log` | Ollama 서버 로그 | ollama serve |
| `~/.god-in-hand/logs/health-*.log` | 헬스 체크 로그 | lib/health.sh |
| `~/.god-in-hand/models/` | 로컬 모델 파일 | lib/models.sh |
| `~/.god-in-hand/hub/` | Hub 대시보드 파일 | Phase 5 |
| `~/.ollama/models/` | Ollama 모델 스토리지 | Ollama |

### 인메모리 상태 (스크립트 변수)

| 변수 | 설정 위치 | 소비 위치 |
|------|-----------|-----------|
| `TOTAL_RAM_GB` | `detect_ram()` | `recommend_models()`, `phase0_preflight()` |
| `ANDROID_API` | `detect_android_version()` | `phase0_preflight()` |
| `CPU_ARCH` | `detect_cpu_arch()` | `phase0_preflight()` |
| `AVAIL_STORAGE_GB` | `detect_storage()` | `phase0_preflight()` |
| `TERMUX_VERSION` | `detect_termux()` | `phase0_preflight()` |
| `NODE_VERSION`, `NODE_MAJOR` | `detect_existing_node()` | `phase1_existing()`, `phase3_install()` |
| `EXISTING_MODELS[]` | `detect_existing_models()` | `phase1_existing()` |
| `MODEL_NAME`, `MODEL_OLLAMA_TAG` 등 | `get_model_info()` | `install_models()` |
| `GIH_LANG` | `detect_language()` | `msg()` 호출 전체 |

### 임시 상태 (curl|bash 전용)

| 상태 | 설명 |
|------|------|
| `PIPED_INSTALL=true` | 파이프 실행 감지, stdin 처리 방식 전환 |
| `exec 3</dev/tty` | 대화형 프롬프트용 stdin 재연결 |
| `</dev/null` 리다이렉트 | pkg/npm 명령의 stdin 소비 방지 |

---

## 6. 오류 처리 흐름

```
명령 실패
  │
  ├── run_cmd() 실패
  │     └── 로그 기록 → GIH_LOG
  │
  ├── 치명적 오류
  │     └── die() 호출
  │           ├── stderr 출력
  │           ├── GIH_LOG에 FATAL 기록
  │           └── exit 1
  │
  └── 비치명적 오류
        └── print_warn() + ((failures++))
              └── Phase 0 완료 시: 실패 수 > 0이면 사용자에게 계속 진행 여부 확인
```
