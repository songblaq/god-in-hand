#!/usr/bin/env bash
# ============================================================================
# God in Hand — i18n (Internationalization) Module
# Supports: English (en), Korean (ko)
# NOTE: Uses case statements instead of associative arrays for curl|bash compat
# ============================================================================

GIH_LANG=""

# ---------------------------------------------------------------------------
# detect_language — Auto-detect system language or use explicit flag
# ---------------------------------------------------------------------------
detect_language() {
    if [[ -n "$GIH_LANG" ]]; then return; fi

    # Android: getprop
    if command -v getprop &>/dev/null; then
        local android_locale
        android_locale=$(getprop persist.sys.locale 2>/dev/null || getprop ro.product.locale 2>/dev/null || echo "")
        if [[ "$android_locale" == ko* ]]; then GIH_LANG="ko"; return; fi
        if [[ -n "$android_locale" ]]; then GIH_LANG="en"; return; fi
    fi

    # POSIX locale
    local sys_lang="${LANG:-${LC_ALL:-${LC_MESSAGES:-}}}"
    if [[ "$sys_lang" == ko* ]]; then GIH_LANG="ko"; return; fi

    GIH_LANG="en"
}

# ---------------------------------------------------------------------------
# msg KEY — Return localized message (case-based, no associative arrays)
# ---------------------------------------------------------------------------
msg() {
    local k="$1"
    if [[ "$GIH_LANG" == "ko" ]]; then
        case "$k" in
            welcome)        echo "🤲 손 안의 신 — 온디바이스 AI 에이전트 설치기" ;;
            phase0)         echo "Phase 0: 사전 점검" ;;
            check_termux)   echo "Termux 버전 확인 중..." ;;
            check_termux_ok) echo "Termux 버전 확인 완료" ;;
            check_termux_fail) echo "Termux는 F-Droid에서 설치해야 합니다 (Play Store 버전은 2020년 이후 미업데이트)." ;;
            check_android)  echo "Android 버전 확인 중..." ;;
            check_android_ok) echo "Android 버전 확인 완료" ;;
            check_android_fail) echo "Android 10+ (API 29+) 필요합니다. 현재 버전: " ;;
            check_arch)     echo "CPU 아키텍처 확인 중..." ;;
            check_arch_ok)  echo "아키텍처 확인 완료 (aarch64)" ;;
            check_arch_fail) echo "aarch64 (arm64) 필요합니다. 감지된 아키텍처: " ;;
            check_ram)      echo "사용 가능 RAM 확인 중..." ;;
            check_ram_ok)   echo "RAM 확인 완료" ;;
            check_ram_warn) echo "사용 가능 RAM이 4GB 미만입니다. 경량 모델만 사용 가능합니다." ;;
            check_storage)  echo "저장 공간 확인 중..." ;;
            check_storage_ok) echo "저장 공간 확인 완료" ;;
            check_storage_fail) echo "최소 10GB 여유 공간이 필요합니다. 현재 여유: " ;;
            check_network)  echo "네트워크 연결 확인 중..." ;;
            check_network_ok) echo "네트워크 연결 확인 완료" ;;
            check_network_fail) echo "네트워크 연결을 감지할 수 없습니다. WiFi 또는 모바일 데이터를 연결해주세요." ;;
            phase1)         echo "Phase 1: 기존 설치 확인" ;;
            found_node)     echo "Node.js 발견: " ;;
            node_upgrade)   echo "Node.js 22+ 필요합니다. 업그레이드할까요? [Y/n]" ;;
            found_openclaw) echo "기존 OpenClaw 설치 발견" ;;
            openclaw_action) echo "기존 OpenClaw를 어떻게 할까요? [U]업데이트 / [R]재설치 / [S]건너뛰기" ;;
            found_models)   echo "기존 모델 파일 발견" ;;
            skip_models)    echo "기존 모델 재다운로드를 건너뛸까요? [Y/n]" ;;
            cleaning_locks) echo "오래된 세션 잠금 파일 정리 중..." ;;
            phase2)         echo "Phase 2: 권한 및 환경 설정" ;;
            storage_perm)   echo "저장소 접근 권한 요청 중..." ;;
            wake_lock)      echo "웨이크 락 설정 중..." ;;
            battery_warn)   echo "⚠️  중요: Termux의 배터리 최적화를 해제하세요!" ;;
            battery_samsung) echo "삼성: 설정 > 배터리 > 앱별 전원 관리 > Termux > 제한 없음" ;;
            phase3)         echo "Phase 3: 핵심 컴포넌트 설치" ;;
            updating_pkg)   echo "패키지 저장소 업데이트 중..." ;;
            installing_deps) echo "의존성 패키지 설치 중..." ;;
            installing_openclaw) echo "OpenClaw 설치 중..." ;;
            model_recommend) echo "디바이스에 추천되는 모델: " ;;
            downloading_model) echo "모델 다운로드 중..." ;;
            model_done)     echo "모델 다운로드 완료" ;;
            phase4)         echo "Phase 4: 검증 및 헬스체크" ;;
            running_doctor) echo "OpenClaw doctor 실행 중..." ;;
            testing_model)  echo "모델 추론 테스트 중..." ;;
            test_ok)        echo "모델 추론 테스트 통과!" ;;
            test_fail)      echo "모델 추론 테스트 실패. 로그를 확인하세요." ;;
            phase5)         echo "Phase 5: 허브 및 멀티디바이스 설정" ;;
            select_role)    echo "디바이스 역할 선택: [H]허브 / [W]워커 / [P]파워 노드" ;;
            done)           echo "✅ 설치 완료!" ;;
            failed)         echo "❌ 설치 실패. 로그 확인: " ;;
            dry_run)        echo "🔍 DRY RUN 모드 — 실제 변경 없음" ;;
            log_location)   echo "로그 파일: " ;;
            dashboard_url)  echo "대시보드 URL: " ;;
            press_enter)    echo "계속하려면 Enter를 누르세요..." ;;
            abort)          echo "설치가 중단되었습니다." ;;
            *)              echo "$k" ;;
        esac
    else
        case "$k" in
            welcome)        echo "🤲 God in Hand — On-device AI Agent Installer" ;;
            phase0)         echo "Phase 0: Pre-flight Checks" ;;
            check_termux)   echo "Checking Termux version..." ;;
            check_termux_ok) echo "Termux version OK" ;;
            check_termux_fail) echo "Termux must be installed from F-Droid (not Play Store). Play Store version is outdated since 2020." ;;
            check_android)  echo "Checking Android version..." ;;
            check_android_ok) echo "Android version OK" ;;
            check_android_fail) echo "Android 10+ (API 29+) required. Your version: " ;;
            check_arch)     echo "Checking CPU architecture..." ;;
            check_arch_ok)  echo "Architecture OK (aarch64)" ;;
            check_arch_fail) echo "aarch64 (arm64) required. Detected: " ;;
            check_ram)      echo "Checking available RAM..." ;;
            check_ram_ok)   echo "RAM OK" ;;
            check_ram_warn) echo "Less than 4GB RAM available. Lightweight models only." ;;
            check_storage)  echo "Checking available storage..." ;;
            check_storage_ok) echo "Storage OK" ;;
            check_storage_fail) echo "At least 10GB free storage required. Available: " ;;
            check_network)  echo "Checking network connection..." ;;
            check_network_ok) echo "Network OK" ;;
            check_network_fail) echo "No network connection detected. Please connect to WiFi or mobile data." ;;
            phase1)         echo "Phase 1: Checking Existing Installations" ;;
            found_node)     echo "Found Node.js: " ;;
            node_upgrade)   echo "Node.js 22+ required. Upgrade? [Y/n]" ;;
            found_openclaw) echo "Found existing OpenClaw installation" ;;
            openclaw_action) echo "What to do with existing OpenClaw? [U]pdate / [R]einstall / [S]kip" ;;
            found_models)   echo "Found existing model files" ;;
            skip_models)    echo "Skip re-downloading existing models? [Y/n]" ;;
            cleaning_locks) echo "Cleaning stale session locks..." ;;
            phase2)         echo "Phase 2: Permissions & Environment" ;;
            storage_perm)   echo "Requesting storage access..." ;;
            wake_lock)      echo "Setting up wake lock..." ;;
            battery_warn)   echo "⚠️  IMPORTANT: Disable battery optimization for Termux!" ;;
            battery_samsung) echo "Samsung: Settings > Battery > App power management > Termux > Unrestricted" ;;
            phase3)         echo "Phase 3: Installing Core Components" ;;
            updating_pkg)   echo "Updating package repository..." ;;
            installing_deps) echo "Installing dependencies..." ;;
            installing_openclaw) echo "Installing OpenClaw..." ;;
            model_recommend) echo "Recommended model for your device: " ;;
            downloading_model) echo "Downloading model..." ;;
            model_done)     echo "Model download complete" ;;
            phase4)         echo "Phase 4: Verification & Health Check" ;;
            running_doctor) echo "Running OpenClaw doctor..." ;;
            testing_model)  echo "Testing model inference..." ;;
            test_ok)        echo "Model inference test passed!" ;;
            test_fail)      echo "Model inference test failed. Check logs." ;;
            phase5)         echo "Phase 5: Hub & Multi-device Setup" ;;
            select_role)    echo "Select device role: [H]ub / [W]orker / [P]ower node" ;;
            done)           echo "✅ Installation complete!" ;;
            failed)         echo "❌ Installation failed. Check log: " ;;
            dry_run)        echo "🔍 DRY RUN mode — no changes will be made" ;;
            log_location)   echo "Log file: " ;;
            dashboard_url)  echo "Dashboard URL: " ;;
            press_enter)    echo "Press Enter to continue..." ;;
            abort)          echo "Installation aborted." ;;
            *)              echo "$k" ;;
        esac
    fi
}

# Initialize
detect_language
