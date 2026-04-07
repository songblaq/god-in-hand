# God in Hand — 모듈 설명

> 각 모듈의 책임 범위, 공개 인터페이스, 주요 함수 목록

---

## 모듈 구조 개요

```
god-in-hand/
├── install.sh          # 5단계 설치 오케스트레이터 (진입점)
├── lib/
│   ├── detect.sh       # 디바이스 및 환경 감지 (18개 함수)
│   ├── models.sh       # 모델 관리 (추천, 다운로드, 검증)
│   ├── health.sh       # 헬스 체크 및 진단 (9개 함수)
│   └── i18n.sh         # 국제화 지원 (en/ko)
├── config/
│   ├── models.json     # 모델 카탈로그 (8개+ 모델 정의)
│   └── devices.json    # 디바이스 프로파일 및 역할 정의
└── hub/
    └── index.html      # 단일 페이지 웹 대시보드
```

---

## install.sh — 설치 오케스트레이터

**역할**: 전체 설치 흐름을 조율하는 최상위 컨트롤러. 라이브러리를 로드하고 5개 단계를 순서대로 실행한다.

**주요 함수**:

| 함수 | 설명 |
|------|------|
| `bootstrap_repo()` | curl 파이프 실행 시 리포지토리 다운로드 |
| `load_libs()` | `lib/` 디렉토리에서 모듈 소스 로드 |
| `phase0_preflight()` | Termux, Android, CPU, RAM, 저장소, 네트워크 사전 점검 |
| `phase1_existing()` | 기존 Node.js, OpenClaw, 모델, 락 파일 감지 |
| `phase2_permissions()` | Termux 스토리지 권한, Wake Lock, Boot 설정 |
| `phase3_install()` | 패키지 설치, OpenClaw, 모델 서빙 엔진, 모델 다운로드 |
| `phase4_verify()` | OpenClaw doctor 실행, 헬스 체크 |
| `phase5_hub()` | Hub 대시보드 배포 및 설정 |
| `main()` | 전체 파이프라인 실행, CLI 인자 처리 |

**전역 변수**:

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `GIH_HOME` | `~/.god-in-hand` | 설치 디렉토리 루트 |
| `GIH_LOG` | `~/.god-in-hand/logs/install-*.log` | 설치 로그 경로 |
| `GIH_VERSION` | `0.1.0` | 현재 버전 |
| `ENGINE` | `ollama` | 모델 서빙 엔진 (ollama/llamacpp) |
| `DRY_RUN` | `false` | dry-run 모드 플래그 |
| `PIPED_INSTALL` | `false` | curl 파이프 실행 감지 플래그 |

---

## lib/detect.sh — 환경 감지 모듈

**역할**: Android/Termux 환경, 하드웨어 스펙, 기존 설치 상태를 탐지하는 모든 감지 함수 집합.

**주요 함수**:

| 함수 | 반환값 | 설명 |
|------|--------|------|
| `detect_termux()` | 0=OK, 1=비Termux, 2=PlayStore버전 | Termux 설치 및 버전 검증 |
| `detect_android_version()` | - | `ANDROID_VERSION`, `ANDROID_API` 설정 |
| `detect_cpu_arch()` | 0=aarch64, 1=기타 | CPU 아키텍처 확인 |
| `detect_ram()` | - | `TOTAL_RAM_MB`, `TOTAL_RAM_GB` 설정 |
| `detect_storage()` | - | `AVAIL_STORAGE_GB` 설정 |
| `detect_network()` | 0=연결됨, 1=불가 | 인터넷 연결 확인 |
| `detect_battery()` | - | 배터리 잔량 및 충전 상태 감지 |
| `detect_device_model()` | - | 디바이스 제조사 및 모델명 |
| `detect_soc()` | - | SoC 칩셋 정보 |
| `detect_thermal()` | - | 열 상태 및 쓰로틀링 감지 |
| `detect_existing_node()` | 0=발견, 1=없음 | Node.js 설치 및 버전 확인 |
| `detect_existing_openclaw()` | 0=발견, 1=없음 | OpenClaw 설치 확인 |
| `detect_existing_ollama()` | 0=발견, 1=없음 | Ollama 설치 확인 |
| `detect_existing_models()` | - | `EXISTING_MODELS` 배열 설정 |
| `detect_stale_locks()` | - | `STALE_LOCKS` 배열 설정 |
| `detect_proot()` | - | proot-distro 및 Ubuntu 설치 확인 |
| `recommend_role()` | hub/worker/power 문자열 | RAM 기반 디바이스 역할 추천 |
| `run_all_detections()` | - | 모든 감지 함수 일괄 실행 |

---

## lib/models.sh — 모델 관리 모듈

**역할**: RAM 기반 모델 추천, `config/models.json` 파싱, 모델 다운로드 및 추론 검증.

**의존성**: `lib/detect.sh` 함수 사용 (RAM 정보)

**주요 함수**:

| 함수 | 입력 | 출력/효과 |
|------|------|-----------|
| `recommend_models(ram_gb)` | RAM(GB) | 공백 구분 모델 ID 목록 출력 |
| `get_model_info(model_id)` | 모델 ID | `MODEL_NAME`, `MODEL_RAM`, `MODEL_OLLAMA_TAG`, `MODEL_HF_REPO`, `MODEL_HF_FILE` 설정 |
| `download_model_ollama(tag)` | Ollama 태그 | ollama pull 실행, 진행 상태 출력 |
| `download_model_hf(repo, file)` | HF 리포, 파일명 | HuggingFace에서 GGUF 다운로드 |
| `verify_model_inference(tag)` | Ollama 태그 | 간단한 추론 테스트 실행, 응답 시간 측정 |
| `install_models(ram_gb, engine)` | RAM, 엔진 | 추천 모델 전체 설치 오케스트레이션 |

**RAM 기반 모델 선택 로직**:

| RAM | 추천 모델 | 역할 |
|-----|-----------|------|
| 14GB+ | gemma4-e4b-q4 + qwen3.5-35b-a3b-q4 + qwen3-0.6b-q8 | Power 노드 |
| 10GB+ | gemma4-e4b-q4 + qwen3-0.6b-q8 | Hub |
| 6GB+ | gemma4-e2b-q4 + qwen3-4b-q4 + qwen3-0.6b-q8 | 일반 Worker |
| 4GB+ | gemma4-e2b-q4 + qwen3-0.6b-q8 | 제한 Worker |
| 4GB 미만 | qwen3-0.6b-q8 | 최소 구성 |

---

## lib/health.sh — 헬스 체크 모듈

**역할**: 런타임 구성 요소의 상태를 점검하고 JSON 형식의 상태 보고를 출력.

**의존성**: `lib/detect.sh` 소스로 로드

**주요 함수**:

| 함수 | 반환값 | 설명 |
|------|--------|------|
| `init_health_log()` | - | 헬스 체크 로그 파일 초기화 |
| `check_ollama_status(api_base)` | 0=OK, 1=미실행, 2=비정상 | Ollama 프로세스 및 API 응답 확인 |
| `check_openclaw_status()` | 0=OK, 1=미실행, 2=비정상 | OpenClaw 게이트웨이 상태 확인 |
| `check_model_loaded(tag)` | 0=로드됨, 1=없음 | 특정 모델 가용성 확인 |
| `check_ram_pressure()` | 0=정상, 1=압박 | 현재 RAM 사용률 평가 |
| `check_thermal()` | 0=정상, 1=과열 | 열 상태 점검 |
| `check_storage_space()` | 0=충분, 1=부족 | 남은 저장 공간 확인 |
| `check_battery_health()` | 0=정상, 1=낮음 | 배터리 잔량 및 상태 확인 |
| `check_network_connectivity()` | 0=연결, 1=단절 | 네트워크 연결 상태 확인 |

---

## lib/i18n.sh — 국제화 모듈

**역할**: 영어/한국어 이중 언어 지원. 연관 배열 대신 `case` 문을 사용하여 curl|bash 호환성 유지.

**의존성**: 없음 (독립 모듈)

**주요 함수**:

| 함수 | 설명 |
|------|------|
| `detect_language()` | Android `getprop` 또는 POSIX `$LANG`으로 언어 자동 감지, `GIH_LANG` 설정 |
| `msg(key)` | 키에 해당하는 현재 언어 메시지 반환 |

**지원 메시지 키**: `welcome`, `phase0`~`phase5`, `check_termux`, `check_android`, `check_arch`, `check_ram`, `check_storage`, `check_network`, `found_node`, `found_openclaw`, `found_models`, `model_recommend`, `installing_*`, `running_doctor`, `abort` 등

---

## config/models.json — 모델 카탈로그

**역할**: 지원 모델의 단일 진실 원본(Single Source of Truth).

**모델 항목 스키마**:

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | string | 모델 고유 식별자 |
| `name` | string | 표시 이름 |
| `family` | string | 모델 패밀리 (gemma, qwen 등) |
| `params` | string | 파라미터 크기 (예: "2B", "4B") |
| `quantization` | string | 양자화 방식 (예: "Q4_K_M") |
| `ram_required_gb` | number | 최소 RAM 요구량 (GB) |
| `features` | array | 지원 기능 (text, image, audio, tool_calling 등) |
| `context_length` | number | 최대 컨텍스트 토큰 수 |
| `ollama_tag` | string | Ollama 다운로드 태그 |
| `hf_repo` | string | HuggingFace 리포지토리 경로 |
| `hf_file` | string | HuggingFace GGUF 파일명 |
| `speed_tier` | string | 속도 등급 (ultrafast/fast/medium) |
| `quality_tier` | string | 품질 등급 (basic/good/excellent) |

**등록 모델 목록**: gemma4-e2b-q4, gemma4-e4b-q4, qwen3-0.6b-q8, qwen3-4b-q4, qwen3.5-35b-a3b-q4 외 3개+

---

## hub/index.html — Hub 대시보드

**역할**: Ollama 및 OpenClaw API를 폴링하여 시스템 상태를 실시간 표시하는 단일 페이지 애플리케이션(SPA).

**기술 스택**: 순수 HTML/CSS/JavaScript (외부 의존성 없음)

**주요 기능**:
- Ollama API (`localhost:11434`) 상태 폴링
- OpenClaw API (`localhost:3000`) 상태 폴링
- 모델 목록 및 RAM 사용량 표시
- 배터리, 온도 등 디바이스 상태 시각화
- 반응형 카드 그리드 레이아웃 (모바일 최적화)
