---
spec_id: SPEC-TEST-001
type: acceptance-criteria
version: "1.0.0"
---

# 인수 기준: Shell 라이브러리 특성 테스트 추가

## TAG: SPEC-TEST-001

## 인수 기준 목록

### AC-1: BATS 테스트 인프라 실행

**Given** BATS 및 헬퍼 라이브러리(bats-support, bats-assert)가 설치되어 있고
**When** `bats tests/` 명령이 실행되면
**Then** 모든 테스트가 TAP 형식으로 출력되며 종료 코드 0으로 완료된다

**검증 방법**: `bats tests/` 실행 후 종료 코드 확인
**관련 요구사항**: REQ-TEST-001

---

### AC-2: i18n 영어 메시지 반환

**Given** i18n 모듈이 로딩되어 있고 GIH_LANG=en으로 설정되어 있을 때
**When** msg("welcome") 함수가 호출되면
**Then** 영어 환영 메시지 문자열을 반환한다

**검증 방법**: BATS assert_output으로 영어 문자열 포함 확인
**관련 요구사항**: REQ-TEST-002

---

### AC-3: detect_ram 메모리 파싱

**Given** /proc/meminfo 픽스처에 8GB 메모리 정보가 포함되어 있고
**When** detect_ram() 함수가 실행되면
**Then** TOTAL_RAM_GB 변수가 8과 동일한 값을 가진다

**검증 방법**: 픽스처 파일 기반 detect_ram 실행 후 TOTAL_RAM_GB 변수 값 검증
**관련 요구사항**: REQ-TEST-003

---

### AC-4: detect_existing_node 버전 파싱

**Given** node --version 명령이 "v22.0.0"을 반환하도록 목킹되어 있고
**When** detect_existing_node() 함수가 실행되면
**Then** NODE_MAJOR 변수가 22와 동일한 값을 가진다

**검증 방법**: node 명령 목킹 후 detect_existing_node 실행, NODE_MAJOR 검증
**관련 요구사항**: REQ-TEST-004

---

### AC-5: recommend_models RAM 기반 추천

**Given** RAM이 6GB로 설정되어 있고
**When** recommend_models(6) 함수가 실행되면
**Then** 출력에 "gemma4" 모델이 포함된다

**검증 방법**: recommend_models 6 실행 후 assert_output --partial "gemma4"
**관련 요구사항**: REQ-TEST-005

---

### AC-6: check_thermal 경고 임계값

**Given** 온도 센서 읽기 값이 55C(55000 millidegree)이고
**When** check_thermal() 함수가 실행되면
**Then** 종료 코드 1(경고)을 반환한다

**검증 방법**: 온도 픽스처 설정 후 check_thermal 실행, 종료 코드 1 확인
**관련 요구사항**: REQ-TEST-006

---

### AC-7: 전체 커버리지 목표

**Given** 모든 테스트 파일이 완성되어 있고
**When** `bats tests/` 명령으로 전체 테스트 스위트가 실행되면
**Then** 최소 20개의 특성 테스트가 존재하고, 47개 함수 중 30% 이상(14개+)의 함수가 테스트 커버리지에 포함된다

**검증 방법**: 테스트 케이스 수 집계 및 테스트 대상 함수 목록 교차 확인
**관련 요구사항**: REQ-TEST-001 ~ REQ-TEST-007

---

## 추가 테스트 시나리오

### i18n 모듈 시나리오

| 시나리오 | Given | When | Then |
|----------|-------|------|------|
| 한국어 메시지 | GIH_LANG=ko | msg("welcome") | 한국어 환영 메시지 반환 |
| 언어 자동 감지 (영어) | LANG=en_US.UTF-8 | detect_language() | GIH_LANG=en 설정 |
| 언어 자동 감지 (한국어) | LANG=ko_KR.UTF-8 | detect_language() | GIH_LANG=ko 설정 |
| 알 수 없는 키 | GIH_LANG=en | msg("nonexistent") | 빈 문자열 또는 기본값 반환 |

### detect 모듈 시나리오

| 시나리오 | Given | When | Then |
|----------|-------|------|------|
| ARM64 아키텍처 | uname -m = "aarch64" | detect_cpu_arch() | CPU_ARCH="aarch64" |
| 4GB RAM | meminfo 픽스처 (4GB) | detect_ram() | TOTAL_RAM_GB=4 |
| 충분한 스토리지 | df 목킹 (20GB 여유) | detect_storage() | STORAGE_FREE_GB>=20 |
| 정상 온도 | thermal 픽스처 (35C) | detect_thermal() | 종료 코드 0 |
| Node 미설치 | node 명령 없음 | detect_existing_node() | NODE_INSTALLED=false |
| Ollama 설치됨 | ollama --version 목킹 | detect_existing_ollama() | OLLAMA_INSTALLED=true |
| 네트워크 연결됨 | curl 성공 목킹 | detect_network() | NETWORK_OK=true |
| 네트워크 단절 | curl 실패 목킹 | detect_network() | NETWORK_OK=false |

### models 모듈 시나리오

| 시나리오 | Given | When | Then |
|----------|-------|------|------|
| 2GB 저사양 | RAM=2 | recommend_models(2) | 경량 모델만 추천 |
| 4GB 중사양 | RAM=4 | recommend_models(4) | 중간 크기 모델 포함 |
| 8GB 고사양 | RAM=8 | recommend_models(8) | 대형 모델 포함 |
| 모델 목록 비어있음 | ollama list 빈 출력 | list_loaded_models() | 빈 목록 반환 |
| 모델 2개 로딩됨 | ollama list 2개 모델 | list_loaded_models() | 2개 모델 정보 반환 |

### health 모듈 시나리오

| 시나리오 | Given | When | Then |
|----------|-------|------|------|
| 메모리 정상 | 사용률 50% | check_ram_pressure() | 종료 코드 0 |
| 메모리 경고 | 사용률 80% | check_ram_pressure() | 종료 코드 1 |
| 메모리 심각 | 사용률 95% | check_ram_pressure() | 종료 코드 2 |
| 온도 정상 | 35C | check_thermal() | 종료 코드 0 |
| 온도 경고 | 55C | check_thermal() | 종료 코드 1 |
| 온도 심각 | 75C | check_thermal() | 종료 코드 2 |
| 스토리지 충분 | 5GB+ 여유 | check_storage_space() | 종료 코드 0 |
| 스토리지 부족 | 1GB 미만 | check_storage_space() | 종료 코드 1 |
| Ollama 실행 중 | pgrep ollama 성공 | check_ollama_status() | 종료 코드 0 |
| Ollama 중지됨 | pgrep ollama 실패 | check_ollama_status() | 종료 코드 1 이상 |
| 배터리 정상 | 충전률 50%+ | check_battery_health() | 종료 코드 0 |
| 배터리 부족 | 충전률 15% 미만 | check_battery_health() | 종료 코드 1 |
| JSON 출력 형식 | 모든 체크 완료 | generate_status_json() | 유효한 JSON 반환 |

## 품질 게이트 기준

| 기준 | 목표값 | 측정 방법 |
|------|--------|-----------|
| 테스트 케이스 수 | 최소 20개 | `bats tests/ --count` |
| 함수 커버리지 | 30%+ (14개/47개) | 테스트 대상 함수 집계 |
| 테스트 통과율 | 100% | `bats tests/` 종료 코드 0 |
| 테스트 격리 | 모든 테스트 독립 실행 가능 | 개별 테스트 파일 단독 실행 검증 |
| CI 호환성 | Linux/macOS에서 실행 가능 | GitHub Actions 또는 로컬 환경 검증 |

## 완료 정의 (Definition of Done)

- [ ] tests/helpers/setup.sh 작성 완료
- [ ] tests/helpers/mocks.sh 작성 완료
- [ ] tests/fixtures/ 디렉토리에 필요한 픽스처 파일 배치
- [ ] tests/unit/test_i18n.bats 작성 및 통과
- [ ] tests/unit/test_detect.bats 작성 및 통과
- [ ] tests/unit/test_models.bats 작성 및 통과
- [ ] tests/unit/test_health.bats 작성 및 통과
- [ ] 전체 `bats tests/` 실행 시 모든 테스트 통과
- [ ] 최소 20개 테스트 케이스 존재
- [ ] 47개 함수 중 30% 이상 커버리지 달성
- [ ] 프로덕션 코드 변경 없음 확인
