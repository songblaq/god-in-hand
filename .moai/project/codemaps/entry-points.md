# God in Hand — 진입점

> 애플리케이션 진입 경로, CLI 명령, API 엔드포인트, 인터페이스 목록

---

## 설치 진입점

### 1. curl|bash 원라이너 (권장)

```bash
curl -sL https://raw.githubusercontent.com/songblaq/god-in-hand/main/install.sh | bash
```

**동작 흐름**:
1. `install.sh` 스트림 수신 및 bash 실행
2. `PIPED_INSTALL=true` 플래그 설정
3. stdin을 `/dev/tty`로 재연결 (대화형 프롬프트용)
4. `bootstrap_repo()` 호출: 리포지토리 git clone 또는 tarball 다운로드
5. `load_libs()` 후 5단계 설치 파이프라인 실행

### 2. 직접 실행

```bash
bash install.sh [OPTIONS]
```

**CLI 옵션**:

| 옵션 | 값 | 기본값 | 설명 |
|------|----|--------|------|
| `--lang` | `en` \| `ko` | 자동 감지 | 설치 언어 강제 지정 |
| `--dry-run` | - | false | 환경 점검만 실행 (설치 안 함) |
| `--skip-model` | - | false | 모델 다운로드 건너뜀 |
| `--device-role` | `hub` \| `worker` \| `power` | 자동 추천 | 디바이스 역할 지정 |
| `--engine` | `ollama` \| `llamacpp` | `ollama` | 모델 서빙 엔진 선택 |
| `--model` | 모델 ID | - | 특정 모델 설치 |
| `--no-color` | - | false | 컬러 출력 비활성화 |
| `--help` \| `-h` | - | - | 도움말 출력 |

**사용 예시**:
```bash
# Dry-run으로 환경만 확인
bash install.sh --dry-run

# 한국어, Hub 역할, 특정 모델 지정
bash install.sh --lang ko --device-role hub --model gemma4-e4b-q4

# llama.cpp 엔진 사용
bash install.sh --engine llamacpp --skip-model
```

---

## 런타임 진입점

### 3. OpenClaw CLI

설치 완료 후 사용 가능한 에이전트 관리 인터페이스:

```bash
# 대화형 에이전트 실행
openclaw

# 온보딩 마법사
openclaw onboard

# 버전 확인
openclaw --version

# 에이전트 상태 확인 (추정)
openclaw doctor
```

**진입 경로**: Termux `$PATH` → npm 글로벌 설치 (`npm install -g openclaw`)

### 4. Hub 대시보드

```
http://localhost:8080
```

**파일**: `hub/index.html`

**접근 방법**:
- Android 기기 브라우저에서 `localhost:8080` 직접 접속
- 설치 완료 후 Phase 5에서 Hub 서버 자동 시작

**제공 정보**:
- Ollama 서비스 상태 (Port 11434)
- OpenClaw 게이트웨이 상태 (Port 3000)
- 로드된 모델 목록 및 RAM 점유율
- 디바이스 배터리 및 온도 상태

---

## API 엔드포인트

### Ollama REST API (Port 11434)

| 메서드 | 경로 | 설명 |
|--------|------|------|
| `GET` | `/api/version` | Ollama 버전 정보 |
| `GET` | `/api/tags` | 설치된 모델 목록 |
| `POST` | `/api/chat` | 채팅 추론 요청 |
| `POST` | `/api/generate` | 텍스트 생성 요청 |
| `POST` | `/api/pull` | 모델 다운로드 |

**내부 사용처**: `lib/health.sh` (상태 확인), `hub/index.html` (폴링), `lib/models.sh` (모델 다운로드)

### OpenClaw API (Port 3000)

| 메서드 | 경로 | 설명 |
|--------|------|------|
| `GET` | `/health` | 서비스 상태 확인 |
| `POST` | `/v1/chat/completions` | OpenAI 호환 채팅 API |

**내부 사용처**: `lib/health.sh` (상태 확인), `hub/index.html` (폴링)

---

## 헬스 체크 진입점

### lib/health.sh 직접 실행

```bash
# install.sh 내에서 Phase 4에서 자동 호출
# 또는 독립 실행 (source 후 함수 호출)
source lib/health.sh
check_ollama_status "http://localhost:11434"
check_openclaw_status
```

### OpenClaw doctor

```bash
# Phase 4에서 자동 실행
openclaw doctor
```

---

## 모델 관리 진입점

### Ollama 직접 명령

```bash
# 모델 다운로드
ollama pull gemma4:e2b
ollama pull qwen3:0.6b

# 모델 실행
ollama run gemma4:e2b

# 실행 중인 모델 목록
ollama ps

# Ollama 서버 시작
ollama serve
```

### install.sh 모델 관련 옵션

```bash
# 특정 모델만 설치
bash install.sh --model gemma4-e4b-q4

# 모델 다운로드 건너뛰기
bash install.sh --skip-model
```
