---
spec_id: SPEC-TEST-001
type: compact
version: "1.0.0"
---

# SPEC-TEST-001 Compact: Shell 라이브러리 특성 테스트 추가

## 요구사항

### REQ-TEST-001: BATS 테스트 인프라 설정
**WHEN** 개발자가 `bats tests/` 명령을 실행하면 **THEN** 시스템은 모든 테스트 스위트를 TAP 출력 형식으로 실행해야 한다.

### REQ-TEST-002: lib/i18n.sh 특성 테스트
**WHEN** msg() 함수가 알려진 키로 호출되면 **THEN** 시스템은 'en'과 'ko' 두 언어에 대해 올바른 지역화 문자열을 반환해야 한다.

### REQ-TEST-003: lib/detect.sh 순수 함수 특성 테스트
**WHEN** 순수 감지 함수가 알려진 시스템 상태로 호출되면 **THEN** 시스템은 예상 값(CPU 아키텍처, RAM, 스토리지, 온도 등)을 반환해야 한다.

### REQ-TEST-004: lib/detect.sh 외부 명령 래퍼 테스트
**WHEN** 감지 함수가 외부 명령(node, ollama, openclaw)을 호출하면 **THEN** 시스템은 목(mock) 명령을 사용하여 버전 출력을 올바르게 파싱해야 한다.

### REQ-TEST-005: lib/models.sh 모델 추천 테스트
**WHEN** recommend_models() 함수가 다양한 RAM 값으로 호출되면 **THEN** 시스템은 RAM 임계값에 기반한 적절한 모델 목록을 반환해야 한다.

### REQ-TEST-006: lib/health.sh 헬스체크 테스트
**WHEN** 헬스체크 함수가 호출되면 **THEN** 시스템은 임계값 기반으로 올바른 상태 코드(0=정상, 1=경고, 2=심각)를 반환해야 한다.

### REQ-TEST-007: 테스트 헬퍼 및 목(Mock) 인프라
**WHEN** 테스트에서 시스템 명령을 목킹해야 할 때 **THEN** 시스템은 getprop, curl, termux-* 명령 및 sysfs 파일 내용을 스텁하기 위한 재사용 가능한 헬퍼 함수를 제공해야 한다.

## 인수 기준

| ID | Given | When | Then |
|----|-------|------|------|
| AC-1 | BATS 설치됨 | `bats tests/` 실행 | 모든 테스트 통과, 종료 코드 0 |
| AC-2 | i18n 로딩, GIH_LANG=en | msg("welcome") 호출 | 영어 환영 문자열 반환 |
| AC-3 | /proc/meminfo 8GB 목킹 | detect_ram() 실행 | TOTAL_RAM_GB=8 |
| AC-4 | node --version="v22.0.0" 목킹 | detect_existing_node() 실행 | NODE_MAJOR=22 |
| AC-5 | RAM=6GB | recommend_models(6) 실행 | "gemma4" 모델 포함 |
| AC-6 | 온도 55C (55000) | check_thermal() 실행 | 종료 코드 1 (경고) |
| AC-7 | 전체 테스트 스위트 | `bats tests/` 실행 | 최소 20개 테스트, 30%+ 함수 커버리지 |

## 수정 대상 파일

### 신규 생성

```
tests/helpers/setup.sh
tests/helpers/mocks.sh
tests/unit/test_i18n.bats
tests/unit/test_detect.bats
tests/unit/test_models.bats
tests/unit/test_health.bats
tests/fixtures/proc_meminfo_8gb
tests/fixtures/proc_meminfo_4gb
tests/fixtures/thermal_normal
tests/fixtures/thermal_warning
tests/fixtures/thermal_critical
tests/fixtures/ollama_list_output
tests/fixtures/battery_normal.json
tests/fixtures/battery_low.json
```

### 수정 파일

- 없음 (프로덕션 코드 수정 금지)

## 제외사항

- install.sh 메인 플로우는 테스트하지 **않는다** (이유: 단위 테스트 범위 초과)
- 실제 네트워크 호출을 수행하지 **않는다** (이유: 테스트 격리 원칙)
- 실제 Termux 전용 API를 호출하지 **않는다** (이유: CI 환경 비호환)
- 프로덕션 코드(lib/*.sh)를 수정하지 **않는다** (이유: 특성 테스트 보존 원칙)
- HARD 난이도 함수(download_model_*, install_models, test_model_inference, run_openclaw_doctor, run_full_health_check)의 실제 외부 서비스 호출은 테스트하지 **않는다** (이유: 네트워크/디스크 I/O 의존성)
