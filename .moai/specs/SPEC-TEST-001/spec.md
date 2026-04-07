---
id: SPEC-TEST-001
version: "1.0.0"
status: draft
created: "2026-04-07"
updated: "2026-04-07"
author: imincheol
priority: high
issue_number: 0
---

# SPEC-TEST-001: Shell 라이브러리 특성 테스트 추가

## 개요

God in Hand 프로젝트의 4개 핵심 라이브러리 모듈(i18n.sh, detect.sh, models.sh, health.sh)에 대한 특성 테스트(Characterization Tests)를 BATS 프레임워크를 사용하여 추가한다. 현재 47개 함수에 대해 테스트 커버리지 0%이며, DDD ANALYZE-PRESERVE-IMPROVE 접근법으로 기존 동작을 먼저 문서화하고 보존한다.

## 환경 (Environment)

- 플랫폼: Android Termux (proot/chroot 환경)
- 셸: Bash 5.x
- 테스트 프레임워크: BATS (Bash Automated Testing System) + bats-support, bats-assert, bats-file
- 대상 모듈: lib/i18n.sh (2개), lib/detect.sh (24개), lib/models.sh (8개), lib/health.sh (13개)
- CI 환경: 로컬 실행 우선, GitHub Actions 연동 가능

## 가정 (Assumptions)

- BATS 및 관련 헬퍼 라이브러리(bats-support, bats-assert)가 테스트 실행 환경에 설치되어 있다
- 프로덕션 코드(lib/*.sh)는 수정하지 않는다 (특성 테스트 원칙)
- 외부 명령(getprop, curl, termux-battery-status 등)은 목(mock) 함수로 대체한다
- /proc/meminfo, sysfs 파일 등은 픽스처(fixture) 파일로 제공한다
- 테스트는 Linux/macOS CI 환경에서도 실행 가능해야 한다

## 요구사항 (Requirements)

### REQ-TEST-001: BATS 테스트 인프라 설정

**WHEN** 개발자가 `bats tests/` 명령을 실행하면 **THEN** 시스템은 모든 테스트 스위트를 TAP 출력 형식으로 실행해야 한다.

- tests/ 디렉토리 구조 생성
- 공통 setup/teardown 헬퍼 파일 제공
- bats-support, bats-assert 헬퍼 로딩 메커니즘 구성

### REQ-TEST-002: lib/i18n.sh 특성 테스트

**WHEN** msg() 함수가 알려진 키로 호출되면 **THEN** 시스템은 'en'과 'ko' 두 언어에 대해 올바른 지역화 문자열을 반환해야 한다.

- detect_language(): 시스템 언어 자동 감지 및 GIH_LANG 설정 검증
- msg($key): 영어/한국어 메시지 반환 정확성 검증
- 알 수 없는 키에 대한 기본 동작 검증

### REQ-TEST-003: lib/detect.sh 순수 함수 특성 테스트

**WHEN** 순수 감지 함수가 알려진 시스템 상태로 호출되면 **THEN** 시스템은 예상 값(CPU 아키텍처, RAM, 스토리지, 온도 등)을 반환해야 한다.

- detect_cpu_arch: /proc/cpuinfo 또는 uname 기반 아키텍처 감지
- detect_ram: /proc/meminfo 파싱으로 총 RAM 계산
- detect_storage: df 출력 파싱으로 가용 스토리지 확인
- detect_thermal: sysfs 온도 파일 읽기
- detect_soc: SoC 정보 감지
- recommend_role: RAM/스토리지 기반 역할 추천
- print_ok/fail/warn/info/step: 출력 포맷팅 함수 검증

### REQ-TEST-004: lib/detect.sh 외부 명령 래퍼 테스트

**WHEN** 감지 함수가 외부 명령(node, ollama, openclaw)을 호출하면 **THEN** 시스템은 목(mock) 명령을 사용하여 버전 출력을 올바르게 파싱해야 한다.

- detect_existing_node: `node --version` 출력 파싱
- detect_existing_ollama: `ollama --version` 출력 파싱
- detect_existing_openclaw: openclaw 존재 확인
- detect_existing_models: 설치된 모델 목록 파싱
- detect_stale_locks: 잠금 파일 감지
- detect_network: 네트워크 연결 확인 (curl 목킹)
- detect_battery: 배터리 상태 감지 (termux-battery-status 목킹)
- detect_proot: proot 환경 감지

### REQ-TEST-005: lib/models.sh 모델 추천 테스트

**WHEN** recommend_models() 함수가 다양한 RAM 값으로 호출되면 **THEN** 시스템은 RAM 임계값에 기반한 적절한 모델 목록을 반환해야 한다.

- recommend_models($ram_gb): RAM 기반 모델 추천 로직 검증
- get_model_info: 모델 메타데이터 반환 검증
- print_model_recommendation: 출력 형식 검증
- list_loaded_models: ollama list 출력 파싱 (목킹)

### REQ-TEST-006: lib/health.sh 헬스체크 테스트

**WHEN** 헬스체크 함수가 호출되면 **THEN** 시스템은 임계값 기반으로 올바른 상태 코드(0=정상, 1=경고, 2=심각)를 반환해야 한다.

- init_health_log: 로그 파일 초기화 검증
- log: 로그 기록 형식 검증
- check_ram_pressure: 메모리 압력 임계값 테스트
- check_thermal: 온도 임계값 테스트
- check_storage_space: 스토리지 임계값 테스트
- check_ollama_status: ollama 프로세스 상태 검증 (목킹)
- check_openclaw_status: openclaw 상태 검증 (목킹)
- check_model_loaded: 모델 로딩 상태 검증
- check_battery_health: 배터리 상태 임계값 테스트
- check_network_connectivity: 네트워크 연결 검증 (목킹)
- generate_status_json: JSON 출력 형식 검증

### REQ-TEST-007: 테스트 헬퍼 및 목(Mock) 인프라

**WHEN** 테스트에서 시스템 명령을 목킹해야 할 때 **THEN** 시스템은 getprop, curl, termux-* 명령 및 sysfs 파일 내용을 스텁하기 위한 재사용 가능한 헬퍼 함수를 제공해야 한다.

- 커스텀 스텁 함수 생성 인프라
- /proc/meminfo, /sys/class/thermal/ 등의 픽스처 파일
- getprop, curl, termux-battery-status 등의 목 함수
- 테스트 격리를 위한 임시 디렉토리 관리

## 명세 (Specifications)

### 테스트 프레임워크 구성

| 항목 | 값 |
|------|-----|
| 프레임워크 | BATS (Bash Automated Testing System) |
| 헬퍼 | bats-support, bats-assert, bats-file |
| 출력 형식 | TAP (Test Anything Protocol) |
| 목킹 전략 | PATH 조작 + 커스텀 스텁 함수 |
| 픽스처 | tests/fixtures/ 디렉토리 |

### 3단계 테스트 접근법

| 단계 | 대상 | 난이도 | 설명 |
|------|------|--------|------|
| Phase 1 | 순수 함수 | EASY | 외부 의존성 없는 함수 (i18n, 포맷팅) |
| Phase 2 | 파일 리더 | EASY-MEDIUM | /proc, sysfs 파일 파싱 함수 |
| Phase 3 | CLI 래퍼 | MEDIUM-HARD | 외부 명령 호출 함수 (목킹 필요) |

### 함수 난이도 분류

| 모듈 | EASY | MEDIUM | HARD | 합계 |
|------|------|--------|------|------|
| lib/i18n.sh | 2 | 0 | 0 | 2 |
| lib/detect.sh | 12 | 4 | 3 | 19 |
| lib/models.sh | 1 | 3 | 4 | 8 |
| lib/health.sh | 5 | 6 | 2 | 13 |
| **합계** | **20** | **13** | **9** | **42** |

> 참고: detect.sh의 print_ok/fail/warn/info/step 5개 함수는 유틸리티로 분류되어 별도 카운트

## 제외사항 (Exclusions - What NOT to Build)

- install.sh 메인 플로우는 테스트하지 **않는다** (이유: 단위 테스트로는 복잡도가 너무 높음, 통합 테스트 범위)
- 실제 네트워크 호출을 수행하지 **않는다** (이유: 테스트 격리 원칙, CI 환경 안정성)
- 실제 Termux 전용 API를 호출하지 **않는다** (이유: CI 환경에서 사용 불가)
- 프로덕션 코드(lib/*.sh)를 수정하지 **않는다** (이유: 특성 테스트는 기존 동작 보존이 목적)
- download_model_ollama, download_model_hf, install_models, test_model_inference의 실제 다운로드/설치 동작은 테스트하지 **않는다** (이유: 네트워크 및 디스크 I/O 의존성)
- run_openclaw_doctor, run_full_health_check의 전체 통합 실행은 테스트하지 **않는다** (이유: 다수 외부 서비스 의존성)

## 추적성 (Traceability)

- TAG: SPEC-TEST-001
- 관련 파일: lib/i18n.sh, lib/detect.sh, lib/models.sh, lib/health.sh
- 출력물: tests/ 디렉토리 전체
