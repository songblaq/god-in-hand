---
spec_id: SPEC-TEST-001
type: implementation-plan
version: "1.0.0"
---

# 구현 계획: Shell 라이브러리 특성 테스트 추가

## TAG: SPEC-TEST-001

## 작업 분해

### Phase 1: 테스트 인프라 구축 [Priority High]

**목표**: BATS 테스트 실행 환경과 공통 헬퍼/목킹 인프라 구성

**생성 파일**:

| 파일 | 설명 |
|------|------|
| `tests/helpers/setup.sh` | 공통 setup/teardown, 소스 로딩, 임시 디렉토리 관리 |
| `tests/helpers/mocks.sh` | getprop, curl, termux-*, ollama, node 등 재사용 목 함수 |
| `tests/fixtures/proc_meminfo_8gb` | /proc/meminfo 목 데이터 (8GB) |
| `tests/fixtures/proc_meminfo_4gb` | /proc/meminfo 목 데이터 (4GB) |
| `tests/fixtures/thermal_normal` | sysfs 온도 파일 (정상: 35C) |
| `tests/fixtures/thermal_warning` | sysfs 온도 파일 (경고: 55C) |
| `tests/fixtures/thermal_critical` | sysfs 온도 파일 (위험: 75C) |
| `tests/fixtures/ollama_list_output` | `ollama list` 명령 출력 샘플 |
| `tests/fixtures/battery_normal.json` | termux-battery-status 정상 출력 |
| `tests/fixtures/battery_low.json` | termux-battery-status 저배터리 출력 |

**핵심 목킹 전략**:

- PATH 조작: 테스트 전용 bin 디렉토리를 PATH 앞에 추가하여 시스템 명령 오버라이드
- 함수 오버라이드: `getprop()`, `curl()` 등을 셸 함수로 재정의
- 파일시스템 목킹: 임시 디렉토리에 /proc, /sys 구조 재현

### Phase 2: lib/i18n.sh 테스트 [Priority High]

**목표**: i18n 모듈의 2개 함수 전체 특성 테스트

**생성 파일**:

| 파일 | 설명 |
|------|------|
| `tests/unit/test_i18n.bats` | detect_language, msg 함수 테스트 |

**테스트 케이스**:

- detect_language(): LANG 환경변수 기반 언어 감지 (en, ko, 기타)
- msg("welcome"): 영어 환영 메시지 반환
- msg("welcome"): 한국어 환영 메시지 반환
- msg("unknown_key"): 알 수 없는 키 기본 동작

### Phase 3: lib/detect.sh 테스트 [Priority High]

**목표**: detect 모듈의 순수 함수 및 외부 명령 래퍼 특성 테스트

**생성 파일**:

| 파일 | 설명 |
|------|------|
| `tests/unit/test_detect.bats` | 순수 감지 함수 + 외부 명령 래퍼 테스트 |

**테스트 케이스 (순수 함수)**:

- detect_cpu_arch: 아키텍처 문자열 반환 검증
- detect_ram: /proc/meminfo 픽스처 기반 RAM 값 계산
- detect_storage: df 출력 목킹 기반 스토리지 계산
- detect_thermal: sysfs 온도 파일 픽스처 읽기
- detect_soc: SoC 정보 감지
- recommend_role: RAM/스토리지 조합별 역할 추천
- print_ok/fail/warn/info/step: 출력 형식 및 색상 코드 검증

**테스트 케이스 (외부 명령 래퍼)**:

- detect_existing_node: `node --version` 목킹 (v22.0.0 -> NODE_MAJOR=22)
- detect_existing_ollama: `ollama --version` 목킹
- detect_existing_openclaw: openclaw 바이너리 존재 확인
- detect_existing_models: 모델 목록 파싱
- detect_stale_locks: 잠금 파일 감지
- detect_network: curl 목킹 기반 네트워크 확인
- detect_battery: termux-battery-status 목킹
- detect_proot: proot 환경 감지

### Phase 4: lib/models.sh 테스트 [Priority Medium]

**목표**: models 모듈의 추천 로직 및 정보 조회 함수 특성 테스트

**생성 파일**:

| 파일 | 설명 |
|------|------|
| `tests/unit/test_models.bats` | 모델 추천, 정보 조회, 목록 함수 테스트 |

**테스트 케이스**:

- recommend_models(2): 저사양 RAM 모델 추천
- recommend_models(4): 중사양 RAM 모델 추천
- recommend_models(6): 고사양 RAM 모델 추천 (gemma4 포함 검증)
- recommend_models(8): 최고사양 RAM 모델 추천
- get_model_info: 모델 메타데이터 반환
- print_model_recommendation: 출력 형식 검증
- list_loaded_models: ollama list 목킹 기반 파싱

### Phase 5: lib/health.sh 테스트 [Priority Medium]

**목표**: health 모듈의 상태 확인 및 임계값 로직 특성 테스트

**생성 파일**:

| 파일 | 설명 |
|------|------|
| `tests/unit/test_health.bats` | 헬스체크 함수 전체 테스트 |

**테스트 케이스**:

- init_health_log: 로그 파일 생성 및 초기화
- log: 로그 메시지 형식 검증
- check_ram_pressure: 정상(0), 경고(1), 심각(2) 반환 검증
- check_thermal: 35C(0), 55C(1), 75C(2) 반환 검증
- check_storage_space: 충분(0), 부족(1), 위험(2) 반환 검증
- check_ollama_status: 프로세스 실행 중/중지 상태 검증 (pgrep 목킹)
- check_openclaw_status: 상태 확인 검증
- check_model_loaded: 모델 로딩 여부 검증
- check_battery_health: 배터리 레벨 임계값 검증
- check_network_connectivity: 네트워크 연결 검증 (curl 목킹)
- generate_status_json: JSON 구조 및 필드 검증

## 전체 파일 목록

### 신규 생성 파일

```
tests/
  helpers/
    setup.sh              # 공통 setup/teardown 헬퍼
    mocks.sh              # 재사용 목 함수 라이브러리
  fixtures/
    proc_meminfo_8gb      # /proc/meminfo 픽스처 (8GB)
    proc_meminfo_4gb      # /proc/meminfo 픽스처 (4GB)
    thermal_normal        # 온도 픽스처 (35C)
    thermal_warning       # 온도 픽스처 (55C)
    thermal_critical      # 온도 픽스처 (75C)
    ollama_list_output    # ollama list 출력 샘플
    battery_normal.json   # 배터리 정상 픽스처
    battery_low.json      # 배터리 저전력 픽스처
  unit/
    test_i18n.bats        # i18n 모듈 테스트
    test_detect.bats      # detect 모듈 테스트
    test_models.bats      # models 모듈 테스트
    test_health.bats      # health 모듈 테스트
```

### 수정 파일

- 없음 (프로덕션 코드 수정 금지 원칙)

## 의존성

| 의존성 | 용도 | 설치 방법 |
|--------|------|-----------|
| bats-core | 테스트 실행기 | `git clone https://github.com/bats-core/bats-core.git` |
| bats-support | 테스트 유틸리티 | `git clone https://github.com/bats-core/bats-support.git` |
| bats-assert | 어서션 라이브러리 | `git clone https://github.com/bats-core/bats-assert.git` |
| bats-file | 파일 어서션 | `git clone https://github.com/bats-core/bats-file.git` |

## 기술적 접근 방식

### 목킹 패턴

**PATH 기반 명령 목킹**:

```
# tests/helpers/mocks.sh 에서 제공
# 임시 bin 디렉토리를 PATH 앞에 추가
# 해당 디렉토리에 목 스크립트 배치
```

**함수 오버라이드 목킹**:

```
# 소스 파일 로딩 후 함수를 재정의하여 목 동작 주입
```

**파일시스템 목킹**:

```
# 임시 디렉토리에 /proc, /sys 구조 재현
# 환경변수로 경로 오버라이드
```

### 테스트 격리 전략

- 각 테스트는 독립적인 임시 디렉토리에서 실행
- setup()에서 환경 초기화, teardown()에서 정리
- 전역 상태 오염 방지를 위한 서브셸 활용
- 환경변수 백업/복원 메커니즘

## 위험 및 대응

| 위험 | 영향 | 대응 방안 |
|------|------|-----------|
| 일부 함수가 하드코딩된 /proc 경로 사용 | 목킹 불가 | 환경변수 기반 경로 오버라이드 패턴 적용, 불가 시 해당 함수 테스트 스킵 |
| getprop이 Android 전용 명령 | CI에서 실행 불가 | 함수 오버라이드로 목킹, Termux 없는 환경 자동 감지 |
| 셸 함수의 전역 변수 부작용 | 테스트 간 상태 누출 | 서브셸 격리 및 명시적 cleanup |
| BATS 의존성 설치 복잡도 | 개발 환경 설정 부담 | git submodule 또는 설치 스크립트 제공 |

## 마일스톤

### Primary Goal: 테스트 인프라 + i18n 테스트

- Phase 1 (인프라) + Phase 2 (i18n) 완료
- 검증: `bats tests/unit/test_i18n.bats` 실행 성공

### Secondary Goal: detect 모듈 테스트

- Phase 3 완료
- 검증: 순수 함수 12개 + 외부 명령 래퍼 7개 테스트 통과

### Tertiary Goal: models + health 테스트

- Phase 4 + Phase 5 완료
- 검증: 전체 `bats tests/` 실행, 최소 20개 테스트 케이스 통과

### Optional Goal: CI 통합

- GitHub Actions 워크플로우 추가
- BATS 의존성 자동 설치
- 테스트 결과 리포트 생성
