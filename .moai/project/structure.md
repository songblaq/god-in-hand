# God in Hand — 프로젝트 구조 문서

## 디렉토리 트리

```
god-in-hand/
├── install.sh              # 5단계 설치 오케스트레이터 (메인 진입점)
├── lib/                    # 핵심 라이브러리 모듈
│   ├── detect.sh           # 디바이스 환경 감지
│   ├── models.sh           # 모델 관리 및 추천
│   ├── health.sh           # 헬스 체크 및 상태 보고
│   └── i18n.sh             # 다국어 지원 (한/영)
├── config/                 # 정적 설정 파일
│   ├── models.json         # 모델 카탈로그 및 요구사항
│   └── devices.json        # 디바이스 프로필 및 역할
├── hub/                    # 웹 대시보드
│   └── index.html          # 단일 파일 관리 대시보드
├── docs/                   # 사용자 가이드 문서
│   ├── ios-setup.md        # iOS 연결 가이드
│   └── troubleshooting.md  # 일반 문제 해결 가이드
└── README.md               # 프로젝트 소개 및 빠른 시작
```

---

## 주요 파일 설명

### install.sh (26.8KB) — 설치 오케스트레이터

전체 설치 프로세스를 조율하는 메인 진입점입니다. `curl | bash` 파이프 방식과 직접 실행 모두 지원합니다.

**처리 단계:**

| 단계 | 이름 | 설명 |
|-----|-----|-----|
| 1 | Preflight | Android 버전(10+), ARM64 아키텍처, Termux 환경 사전 점검 |
| 2 | Existing Check | 기존 설치 감지 및 업그레이드/재설치 선택 |
| 3 | Permissions | 스토리지, 네트워크, Termux:API 권한 확인 |
| 4 | Install | Node.js, Ollama, OpenClaw, 의존성 패키지 설치 |
| 5 | Verify + Hub | 설치 검증, 헬스 체크 실행, Hub 대시보드 활성화 |

**지원 CLI 옵션:**

```
--lang ko|en       # 인터페이스 언어 선택
--dry-run          # 실제 설치 없이 시뮬레이션
--skip-model       # 모델 다운로드 건너뜀
--device-role      # 역할 지정 (hub|worker|power)
--engine llamacpp  # Ollama 대신 llama.cpp 사용
--model <name>     # 특정 모델 지정
--no-color         # 컬러 출력 비활성화
```

**lib/ 모듈 의존성:**

```
install.sh
  ├── source lib/detect.sh    # 환경 감지
  ├── source lib/models.sh    # 모델 관리
  ├── source lib/health.sh    # 헬스 체크
  └── source lib/i18n.sh      # 다국어 메시지
```

---

### lib/detect.sh (11.6KB) — 디바이스 환경 감지

15개 이상의 감지 함수를 포함하며, install.sh와 health.sh에서 공통으로 사용됩니다.

**주요 감지 기능:**

| 함수 | 감지 항목 |
|-----|---------|
| `detect_termux` | Termux 환경 여부 |
| `detect_android_version` | Android 버전 (최소 10 요구) |
| `detect_ram` | 가용 RAM (MB 단위) |
| `detect_cpu` | CPU 코어 수, ARM64 아키텍처 확인 |
| `detect_battery` | 배터리 잔량 및 충전 상태 |
| `detect_thermal` | 열 상태 및 쓰로틀링 여부 |
| `detect_soc` | SoC 모델명 (Snapdragon, Exynos 등) |
| `detect_device_model` | 디바이스 제조사 및 모델명 |

---

### lib/models.sh (10.3KB) — 모델 관리

RAM 기반 모델 추천, 다운로드, 추론 테스트를 담당합니다.

**주요 기능:**

- `recommend_models`: 감지된 RAM 용량에 따라 최적 모델 조합 추천
- `download_model`: Ollama 태그 또는 HuggingFace 저장소에서 모델 다운로드
- `test_inference`: 설치된 모델로 간단한 추론 테스트 실행
- `config/models.json` 파일을 파싱하여 모델 정보 로드

---

### lib/health.sh (11.8KB) — 헬스 체크

9개 이상의 헬스 체크 함수와 JSON 형식 상태 출력을 제공합니다.

**헬스 체크 항목:**

| 체크 항목 | 설명 |
|---------|-----|
| Ollama | 서비스 실행 여부, API 응답 확인 |
| OpenClaw | 에이전트 런타임 상태 |
| Models | 로드된 모델 목록 및 상태 |
| RAM | 가용 메모리 및 스왑 사용량 |
| Thermal | 디바이스 온도 및 쓰로틀링 상태 |
| Storage | 디스크 사용량 및 여유 공간 |
| Battery | 배터리 잔량 및 충전 상태 |
| Network | 로컬 네트워크 및 포트 접근성 |

JSON 출력 형식으로 Hub 대시보드에서 실시간으로 상태를 표시합니다.

---

### lib/i18n.sh (6.2KB) — 다국어 지원

Bash case문 기반의 순수 쉘 다국어 지원 모듈입니다. `gettext` 등 외부 도구에 의존하지 않아 `curl | bash` 파이프 환경에서도 동작합니다.

**지원 언어:** 한국어(`ko`), 영어(`en`)

**사용 방식:**

```bash
source lib/i18n.sh
set_language "ko"
msg "install_start"  # "설치를 시작합니다..." 출력
```

---

### config/models.json (7KB) — 모델 카탈로그

8개 이상의 모델 정보를 담은 정적 설정 파일입니다.

**각 모델 항목 구성:**

```json
{
  "name": "모델명",
  "ram_required_mb": 4096,
  "quantization": "q4_k_m",
  "features": ["chat", "code"],
  "ollama_tag": "qwen3:0.6b",
  "hf_repo": "Qwen/Qwen3-0.6B-GGUF"
}
```

---

### config/devices.json (3.1KB) — 디바이스 프로필

멀티 디바이스 메시 구성에 사용되는 역할별 RAM 임계값을 정의합니다.

| 역할 | RAM 임계값 | 주요 역할 |
|-----|---------|---------|
| hub | 12GB+   | 기본 게이트웨이, 쿼리 라우팅 |
| worker | 8GB+ | 백그라운드 작업 처리 |
| power | 16GB+  | 복잡한 추론 작업 |

---

### hub/index.html (19.5KB) — 웹 대시보드

외부 의존성이 없는 단일 파일 웹 애플리케이션입니다.

**구성 요소:**

- 실시간 디바이스 상태 모니터링 패널 (RAM, CPU, 배터리, 온도)
- 연결된 디바이스 노드 목록 및 라우팅 설정
- 스킬 활성화/비활성화 토글
- 모델 다운로드 및 관리 인터페이스
- Ollama API(`localhost:11434`)와 직접 통신

---

### docs/ios-setup.md — iOS 연결 가이드

iOS 기기를 Android Hub에 연결하는 방법을 설명합니다.

- ExecuTorch를 이용한 iOS 로컬 실행 방법
- WiFi를 통한 Android Hub 페어링 절차
- mDNS 기반 자동 검색 설정

### docs/troubleshooting.md — 문제 해결 가이드

일반적인 설치 및 실행 문제에 대한 해결책을 제공합니다.

- Samsung OneUI 특유의 호환성 이슈
- 열 쓰로틀링으로 인한 성능 저하 대응
- WiFi mDNS 멀티캐스트 문제 해결

---

## 모듈 의존성 그래프

```
install.sh (진입점)
├── lib/i18n.sh        ← 메시지 출력 (독립 모듈)
├── lib/detect.sh      ← 환경 감지 (독립 모듈)
│   └── config/devices.json  ← 역할 임계값 참조
├── lib/models.sh      ← 모델 관리
│   ├── lib/detect.sh  ← RAM 정보 활용
│   └── config/models.json   ← 모델 카탈로그 참조
└── lib/health.sh      ← 헬스 체크
    └── lib/detect.sh  ← 디바이스 상태 활용

hub/index.html (독립 실행)
└── Ollama REST API (localhost:11434) ← 런타임 통신
```

**설계 원칙:**

- 각 `lib/` 모듈은 독립적으로 `source` 가능하도록 설계
- `config/` 파일은 쉘 스크립트와 웹 대시보드 양측에서 참조
- `hub/index.html`은 설치 후 독립 실행되며 설치 스크립트와 런타임 의존성 없음
