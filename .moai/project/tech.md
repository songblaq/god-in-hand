# God in Hand — 기술 스택 문서

## 기술 스택 개요

God in Hand는 Android Termux 환경에서의 최대 호환성과 설치 용이성을 위해 의도적으로 경량 기술 스택을 선택했습니다.

| 계층 | 기술 | 역할 |
|-----|-----|-----|
| 설치 오케스트레이션 | Bash (Shell Script) | 5단계 설치 자동화 |
| 모델 서빙 | Ollama / llama.cpp | LLM 로컬 추론 엔진 |
| 에이전트 런타임 | OpenClaw (Node.js) | AI 에이전트 실행 프레임워크 |
| 웹 대시보드 | HTML/CSS/JavaScript (단일 파일) | 관리 인터페이스 |
| 설정 관리 | JSON | 모델 카탈로그, 디바이스 프로필 |
| 다국어 지원 | Bash case문 | 인터페이스 현지화 |

---

## 주요 언어 및 프레임워크

### Bash (Shell Script) — 핵심 구현 언어

전체 설치 로직과 라이브러리 모듈이 Bash로 작성되어 있습니다.

**선택 이유:**

- Termux는 기본적으로 Bash를 지원하므로 추가 런타임 설치가 불필요
- `curl | bash` 파이프 방식 설치를 위해 단일 인터프리터로 전체 로직 구현 가능
- Python, Ruby 등 스크립팅 언어와 달리 Termux에서 패키지 설치 없이 즉시 실행
- 시스템 명령(`pkg`, `termux-setup-storage`, `termux-api`)과 직접 통합

**버전 요건:** Bash 4.0+ (Android 10 기본 제공)

**주요 내장 기능 활용:**
- `case`문 기반 다국어 처리 (`gettext` 불필요)
- Process substitution을 통한 JSON 파싱 (`jq` 선택적 의존)
- `curl`을 이용한 REST API 통신 (Ollama, HuggingFace)

---

### Ollama — LLM 서빙 엔진 (기본)

**버전 요건:** 0.20+

**선택 이유:**

- ARM64 Android 바이너리를 공식 지원
- REST API(`localhost:11434`)를 통해 쉘 스크립트와 웹 대시보드 모두에서 접근 가능
- HuggingFace GGUF 모델을 포함한 광범위한 모델 생태계 지원
- 모델 다운로드, 로딩, 언로딩 전체 수명 주기 관리

**API 엔드포인트:**

```
POST /api/generate   # 텍스트 생성
POST /api/chat       # 대화형 채팅
GET  /api/tags       # 로드된 모델 목록
POST /api/pull       # 모델 다운로드
```

---

### llama.cpp — LLM 서빙 엔진 (대안)

`--engine llamacpp` 옵션으로 Ollama 대신 사용 가능합니다.

**선택 이유:**

- Ollama보다 낮은 메모리 오버헤드
- GGUF 형식 모델을 직접 실행
- GPU 가속(Vulkan) 지원 가능

**빌드 요건:** cmake (선택적 의존성, llama.cpp 선택 시 필요)

---

### OpenClaw — AI 에이전트 런타임

Node.js 기반 AI 에이전트 프레임워크로, Ollama API를 통해 LLM과 통신하며 실제 작업을 수행합니다.

**버전 요건:** Node.js 22+

**선택 이유:**

- JavaScript 에코시스템의 풍부한 플러그인 지원
- 비동기 이벤트 기반 아키텍처로 에이전트 동시 실행에 적합
- Termux에서 Node.js 22 공식 지원

**지원 스킬:**

| 스킬 | 설명 |
|-----|-----|
| Browser | Chromium 기반 웹 자동화 |
| Files | 파일 시스템 읽기/쓰기/검색 |
| Cron | 예약 작업 등록 및 실행 |
| Camera | Termux:API를 통한 카메라 접근 |
| GPS | 위치 정보 획득 및 지오펜싱 |
| Termux:API | Android 시스템 알림, 클립보드, 진동 등 |

---

### HTML/CSS/JavaScript — 웹 대시보드

`hub/index.html`은 외부 프레임워크나 빌드 도구 없이 작성된 단일 파일 애플리케이션입니다.

**선택 이유:**

- 빌드 단계 없이 Android 기본 브라우저에서 바로 실행
- Termux에서 파일 서버 없이 `file://` 프로토콜로도 접근 가능
- React, Vue 등 프레임워크 의존성 배제로 업데이트 단순화

**기술 구성:**

- Vanilla JavaScript (ES2020+) — 동적 UI 업데이트
- CSS Grid/Flexbox — 반응형 레이아웃
- Fetch API — Ollama REST API와 비동기 통신
- WebSocket — 실시간 상태 스트리밍 (계획)

---

### JSON — 설정 파일 형식

`config/models.json`과 `config/devices.json`은 정적 설정 데이터를 저장합니다.

**선택 이유:**

- Bash에서 `jq` 또는 `grep`/`awk`로 파싱 가능
- JavaScript 웹 대시보드에서 `fetch()`로 직접 로드 가능
- 사람이 읽기 쉬운 형식으로 커뮤니티 기여 촉진

---

## 개발 환경 요건

### 타겟 플랫폼

| 항목 | 요건 |
|-----|-----|
| 운영체제 | Android 10 이상 |
| 아키텍처 | ARM64 (aarch64) |
| 런타임 환경 | Termux (F-Droid 버전 권장) |
| 최소 RAM | 4GB (실용적 사용은 8GB 이상 권장) |
| 저장공간 | 10GB 이상 (모델 크기에 따라 가변) |

### 빌드 및 개발 도구

**필수 의존성:**

| 패키지 | 버전 | 용도 |
|-------|-----|-----|
| Node.js | 22+ | OpenClaw 에이전트 런타임 |
| Ollama | 0.20+ | LLM 서빙 엔진 |
| Git | 2.x | 저장소 클론 및 업데이트 |
| Python | 3.x | 일부 유틸리티 스크립트 |
| curl | 7.x | HTTP 통신, 설치 스크립트 다운로드 |
| proot-distro | 최신 | chroot 환경 관리 |

**선택적 의존성:**

| 패키지 | 버전 | 용도 |
|-------|-----|-----|
| cmake | 3.x | llama.cpp 소스 빌드 시 필요 |
| jq | 1.6+ | JSON 파싱 개선 (없으면 grep/awk 사용) |
| Termux:API | 최신 | 카메라, GPS, 알림 등 Android API 접근 |

---

## 배포 및 설치 구성

### 설치 방식

**원클릭 설치 (curl|bash):**

```bash
curl -fsSL https://raw.githubusercontent.com/songblaq/god-in-hand/main/install.sh | bash
```

**수동 설치:**

```bash
git clone https://github.com/songblaq/god-in-hand
cd god-in-hand
bash install.sh --lang ko
```

**드라이런 (시뮬레이션):**

```bash
bash install.sh --dry-run --lang ko
```

### 설치 스크립트 보안 고려사항

- `curl | bash` 방식의 코드 인젝션 위험을 방지하기 위해 체크섬 검증 권장
- 설치 전 스크립트 내용을 `curl -fsSL URL | less`로 미리 검토 가능
- `--dry-run` 모드로 실제 변경 없이 설치 과정 확인 가능

---

## 모델 서빙 아키텍처

```
[사용자/에이전트]
      |
      v
[OpenClaw 에이전트 런타임 - Node.js]
      |  REST API 호출
      v
[Ollama 서비스 - localhost:11434]
      |
      v
[GGUF 모델 파일 - ARM64 최적화]
      |  (선택: llama.cpp 직접 추론)
      v
[Android 커널 - ARM64 NEON/SVE 최적화]
```

**멀티 디바이스 메시 아키텍처:**

```
[iOS 기기] --WiFi--> [Android Hub (12GB+)]
                          |
              +-----------+-----------+
              |                       |
    [Worker 노드 (8GB)]    [Power 노드 (16GB+)]
```

Hub 노드는 쿼리의 복잡도와 각 노드의 가용 리소스를 기반으로 작업을 자동 분배합니다.

---

## 외부 서비스 의존성

God in Hand는 설치 시를 제외하고 외부 서비스에 의존하지 않습니다.

| 서비스 | 사용 시점 | 설명 |
|-------|---------|-----|
| Ollama 공식 레지스트리 | 설치/모델 다운로드 시 | GGUF 모델 파일 다운로드 |
| HuggingFace Hub | 설치/모델 다운로드 시 | 대안 모델 소스 |
| GitHub | 설치 스크립트 다운로드 시 | curl|bash 원본 소스 |
| npm 레지스트리 | OpenClaw 설치 시 | Node.js 패키지 의존성 |
| Termux 패키지 서버 | 의존성 설치 시 | pkg 패키지 관리자 소스 |

**런타임 시 외부 통신 없음**: 설치 완료 후 모든 처리는 디바이스 내에서 완결됩니다.
