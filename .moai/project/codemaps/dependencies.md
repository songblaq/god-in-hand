# God in Hand — 의존성 그래프

> 내부 모듈 관계, 외부 패키지, 런타임 서비스 의존성

---

## 내부 모듈 의존성

```
install.sh
  ├── source lib/i18n.sh          (언어 감지, msg() 함수 제공)
  ├── source lib/detect.sh        (환경 감지 함수 전체 제공)
  ├── source lib/models.sh        (모델 관리 함수 제공)
  │     └── uses detect.sh       (TOTAL_RAM_GB 변수 참조)
  └── source lib/health.sh       (헬스 체크 함수 제공)
        └── source detect.sh    (감지 함수 재사용)

lib/i18n.sh     → 의존성 없음 (독립 모듈)
lib/detect.sh   → 의존성 없음 (독립 모듈)
lib/models.sh   → lib/detect.sh (RAM 변수 참조)
lib/health.sh   → lib/detect.sh (source로 직접 로드)

hub/index.html  → 런타임 API 폴링 (Ollama :11434, OpenClaw :3000)
```

**로드 순서** (install.sh load_libs 기준):
1. `lib/i18n.sh` — 메시지 함수 준비
2. `lib/detect.sh` — 환경 감지 기반 함수 준비
3. `lib/models.sh` — detect.sh 변수 참조 가능한 시점에 로드
4. `lib/health.sh` — detect.sh를 내부에서 직접 source

---

## 설정 파일 참조

```
lib/models.sh
  └── reads config/models.json   (MODELS_JSON 변수로 경로 지정)
        파싱 우선순위:
        1. python3 -c "import json..." (파이썬 가용 시)
        2. grep 휴리스틱 (폴백)

install.sh
  └── reads config/devices.json  (디바이스 역할 프로파일 참조)
```

---

## 외부 런타임 의존성

### 설치 시 필요한 패키지 (Termux pkg)

| 패키지 | 용도 | 필수/선택 |
|--------|------|-----------|
| `curl` | 파일 다운로드, API 호출 | 필수 |
| `wget` | 대체 다운로드 | 선택 |
| `git` | 리포지토리 클론 | 필수 |
| `nodejs-lts` | OpenClaw 실행 (v22+) | 필수 |
| `python` | models.json JSON 파싱 | 권장 |
| `build-essential` | llama.cpp 빌드 | llama.cpp 선택 시 |
| `cmake` | llama.cpp 빌드 시스템 | llama.cpp 선택 시 |
| `proot-distro` | Ubuntu chroot 환경 | 선택 |

### npm 패키지

| 패키지 | 버전 | 용도 |
|--------|------|------|
| `openclaw` | latest | AI 에이전트 게이트웨이 |

### 외부 서비스 (설치 시 네트워크 필요)

| 서비스 | URL | 용도 |
|--------|-----|------|
| Ollama 설치 스크립트 | `https://ollama.com/install.sh` | Ollama 자동 설치 |
| GitHub | `https://github.com/songblaq/god-in-hand` | 리포지토리 클론 |
| GitHub (tarball) | `https://github.com/songblaq/god-in-hand/archive/main.tar.gz` | git 없을 때 폴백 |
| HuggingFace | `https://huggingface.co` | GGUF 모델 다운로드 |
| llama.cpp | `https://github.com/ggml-org/llama.cpp` | llama.cpp 소스 클론 |
| npm registry | `https://registry.npmjs.org` | openclaw 패키지 |

---

## 런타임 서비스 의존성

```
사용자/브라우저
  └── hub/index.html (Port 8080)
        ├── GET http://localhost:11434/api/version    (Ollama 버전)
        ├── GET http://localhost:11434/api/tags       (모델 목록)
        └── GET http://localhost:3000/health          (OpenClaw 상태)

OpenClaw (Port 3000)
  └── POST http://localhost:11434/api/chat           (모델 추론 요청)

lib/health.sh
  ├── curl http://localhost:11434/api/version        (Ollama 상태)
  └── curl http://localhost:3000/health              (OpenClaw 상태)
```

---

## 시스템 명령 의존성

`lib/detect.sh`에서 사용하는 Android/Termux 전용 명령:

| 명령 | 용도 | 가용 환경 |
|------|------|-----------|
| `getprop` | Android 시스템 속성 읽기 | Android/Termux |
| `dpkg` | 패키지 버전 확인 | Termux |
| `termux-info` | Termux 앱 정보 | Termux |
| `termux-setup-storage` | 스토리지 권한 요청 | Termux:API |
| `termux-wake-lock` | Wake Lock 획득 | Termux:API |
| `pgrep` | 프로세스 존재 확인 | 표준 Unix |
| `free` | RAM 사용량 | 표준 Unix |
| `df` | 디스크 사용량 | 표준 Unix |

---

## 의존성 충돌 및 주의사항

1. **Termux Play Store 버전**: F-Droid 버전과 패키지 호환성 불일치. `detect_termux()`가 사전 차단.
2. **Node.js 버전**: v22 미만 시 OpenClaw 동작 불안정. `install.sh`가 자동 업그레이드 시도.
3. **python3 부재**: `models.json` 파싱 시 grep 폴백으로 전환되나 복잡한 쿼리에서 부정확할 수 있음.
4. **Ollama 자동 설치 실패**: `ollama.com/install.sh` 실패 시 `pkg install ollama` 폴백 시도.
