#!/usr/bin/env bash
# ============================================================================
# God in Hand — i18n (Internationalization) Module
# Supports: English (en), Korean (ko)
# Usage: source lib/i18n.sh [--lang en|ko]
# ============================================================================

GIH_LANG=""

# ---------------------------------------------------------------------------
# detect_language — Auto-detect system language or use explicit flag
# Priority: 1) --lang flag  2) Android locale  3) $LANG env  4) fallback "en"
# ---------------------------------------------------------------------------
detect_language() {
    # 1) Check if --lang was passed to the parent script
    if [[ -n "$GIH_LANG" ]]; then
        return
    fi

    # 2) Android: getprop (works in Termux without root)
    if command -v getprop &>/dev/null; then
        local android_locale
        android_locale=$(getprop persist.sys.locale 2>/dev/null || getprop ro.product.locale 2>/dev/null || echo "")
        if [[ "$android_locale" == ko* ]]; then
            GIH_LANG="ko"; return
        elif [[ -n "$android_locale" ]]; then
            GIH_LANG="en"; return
        fi
    fi

    # 3) Standard POSIX locale
    local sys_lang="${LANG:-${LC_ALL:-${LC_MESSAGES:-}}}"
    if [[ "$sys_lang" == ko* ]]; then
        GIH_LANG="ko"; return
    fi

    # 4) Default fallback
    GIH_LANG="en"
}

# ---------------------------------------------------------------------------
# parse_lang_flag — Call from parent script argument parser
# ---------------------------------------------------------------------------
parse_lang_flag() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lang)
                if [[ "$2" == "ko" || "$2" == "en" ]]; then
                    GIH_LANG="$2"
                fi
                shift 2
                ;;
            *) shift ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Message catalog — msg KEY
# Returns the localized string for a given key
# ---------------------------------------------------------------------------
declare -A MSG_EN
declare -A MSG_KO

# --- Phase 0: Pre-checks ---
MSG_EN[welcome]="🤲 God in Hand — On-device AI Agent Installer"
MSG_KO[welcome]="🤲 손 안의 신 — 온디바이스 AI 에이전트 설치기"

MSG_EN[phase0]="Phase 0: Pre-flight Checks"
MSG_KO[phase0]="Phase 0: 사전 점검"

MSG_EN[check_termux]="Checking Termux version..."
MSG_KO[check_termux]="Termux 버전 확인 중..."

MSG_EN[check_termux_ok]="Termux version OK"
MSG_KO[check_termux_ok]="Termux 버전 확인 완료"

MSG_EN[check_termux_fail]="Termux must be installed from F-Droid (not Play Store). Play Store version is outdated since 2020."
MSG_KO[check_termux_fail]="Termux는 F-Droid에서 설치해야 합니다 (Play Store 버전은 2020년 이후 미업데이트)."

MSG_EN[check_android]="Checking Android version..."
MSG_KO[check_android]="Android 버전 확인 중..."

MSG_EN[check_android_ok]="Android version OK"
MSG_KO[check_android_ok]="Android 버전 확인 완료"

MSG_EN[check_android_fail]="Android 10+ (API 29+) required. Your version: "
MSG_KO[check_android_fail]="Android 10+ (API 29+) 필요합니다. 현재 버전: "

MSG_EN[check_arch]="Checking CPU architecture..."
MSG_KO[check_arch]="CPU 아키텍처 확인 중..."

MSG_EN[check_arch_ok]="Architecture OK (aarch64)"
MSG_KO[check_arch_ok]="아키텍처 확인 완료 (aarch64)"

MSG_EN[check_arch_fail]="aarch64 (arm64) required. Detected: "
MSG_KO[check_arch_fail]="aarch64 (arm64) 필요합니다. 감지된 아키텍처: "

MSG_EN[check_ram]="Checking available RAM..."
MSG_KO[check_ram]="사용 가능 RAM 확인 중..."

MSG_EN[check_ram_ok]="RAM OK"
MSG_KO[check_ram_ok]="RAM 확인 완료"

MSG_EN[check_ram_warn]="Less than 4GB RAM available. Lightweight models only."
MSG_KO[check_ram_warn]="사용 가능 RAM이 4GB 미만입니다. 경량 모델만 사용 가능합니다."

MSG_EN[check_storage]="Checking available storage..."
MSG_KO[check_storage]="저장 공간 확인 중..."

MSG_EN[check_storage_ok]="Storage OK"
MSG_KO[check_storage_ok]="저장 공간 확인 완료"

MSG_EN[check_storage_fail]="At least 10GB free storage required. Available: "
MSG_KO[check_storage_fail]="최소 10GB 여유 공간이 필요합니다. 현재 여유: "

MSG_EN[check_network]="Checking network connection..."
MSG_KO[check_network]="네트워크 연결 확인 중..."

MSG_EN[check_network_ok]="Network OK"
MSG_KO[check_network_ok]="네트워크 연결 확인 완료"

MSG_EN[check_network_fail]="No network connection detected. Please connect to WiFi or mobile data."
MSG_KO[check_network_fail]="네트워크 연결을 감지할 수 없습니다. WiFi 또는 모바일 데이터를 연결해주세요."

# --- Phase 1: Existing installs ---
MSG_EN[phase1]="Phase 1: Checking Existing Installations"
MSG_KO[phase1]="Phase 1: 기존 설치 확인"

MSG_EN[found_node]="Found Node.js: "
MSG_KO[found_node]="Node.js 발견: "

MSG_EN[node_upgrade]="Node.js 22+ required. Upgrade? [Y/n]"
MSG_KO[node_upgrade]="Node.js 22+ 필요합니다. 업그레이드할까요? [Y/n]"

MSG_EN[found_openclaw]="Found existing OpenClaw installation"
MSG_KO[found_openclaw]="기존 OpenClaw 설치 발견"

MSG_EN[openclaw_action]="What to do with existing OpenClaw? [U]pdate / [R]einstall / [S]kip"
MSG_KO[openclaw_action]="기존 OpenClaw를 어떻게 할까요? [U]업데이트 / [R]재설치 / [S]건너뛰기"

MSG_EN[found_models]="Found existing model files"
MSG_KO[found_models]="기존 모델 파일 발견"

MSG_EN[skip_models]="Skip re-downloading existing models? [Y/n]"
MSG_KO[skip_models]="기존 모델 재다운로드를 건너뛸까요? [Y/n]"

MSG_EN[cleaning_locks]="Cleaning stale session locks..."
MSG_KO[cleaning_locks]="오래된 세션 잠금 파일 정리 중..."

# --- Phase 2: Permissions ---
MSG_EN[phase2]="Phase 2: Permissions & Environment"
MSG_KO[phase2]="Phase 2: 권한 및 환경 설정"

MSG_EN[storage_perm]="Requesting storage access..."
MSG_KO[storage_perm]="저장소 접근 권한 요청 중..."

MSG_EN[wake_lock]="Setting up wake lock..."
MSG_KO[wake_lock]="웨이크 락 설정 중..."

MSG_EN[battery_warn]="⚠️  IMPORTANT: Disable battery optimization for Termux!"
MSG_KO[battery_warn]="⚠️  중요: Termux의 배터리 최적화를 해제하세요!"

MSG_EN[battery_samsung]="Samsung: Settings > Battery > App power management > Termux > Unrestricted"
MSG_KO[battery_samsung]="삼성: 설정 > 배터리 > 앱별 전원 관리 > Termux > 제한 없음"

# --- Phase 3: Installation ---
MSG_EN[phase3]="Phase 3: Installing Core Components"
MSG_KO[phase3]="Phase 3: 핵심 컴포넌트 설치"

MSG_EN[updating_pkg]="Updating package repository..."
MSG_KO[updating_pkg]="패키지 저장소 업데이트 중..."

MSG_EN[installing_deps]="Installing dependencies..."
MSG_KO[installing_deps]="의존성 패키지 설치 중..."

MSG_EN[installing_openclaw]="Installing OpenClaw..."
MSG_KO[installing_openclaw]="OpenClaw 설치 중..."

MSG_EN[model_recommend]="Recommended model for your device: "
MSG_KO[model_recommend]="디바이스에 추천되는 모델: "

MSG_EN[downloading_model]="Downloading model..."
MSG_KO[downloading_model]="모델 다운로드 중..."

MSG_EN[model_done]="Model download complete"
MSG_KO[model_done]="모델 다운로드 완료"

# --- Phase 4: Verification ---
MSG_EN[phase4]="Phase 4: Verification & Health Check"
MSG_KO[phase4]="Phase 4: 검증 및 헬스체크"

MSG_EN[running_doctor]="Running OpenClaw doctor..."
MSG_KO[running_doctor]="OpenClaw doctor 실행 중..."

MSG_EN[testing_model]="Testing model inference..."
MSG_KO[testing_model]="모델 추론 테스트 중..."

MSG_EN[test_ok]="Model inference test passed!"
MSG_KO[test_ok]="모델 추론 테스트 통과!"

MSG_EN[test_fail]="Model inference test failed. Check logs."
MSG_KO[test_fail]="모델 추론 테스트 실패. 로그를 확인하세요."

# --- Phase 5: Hub setup ---
MSG_EN[phase5]="Phase 5: Hub & Multi-device Setup"
MSG_KO[phase5]="Phase 5: 허브 및 멀티디바이스 설정"

MSG_EN[select_role]="Select device role: [H]ub / [W]orker / [P]ower node"
MSG_KO[select_role]="디바이스 역할 선택: [H]허브 / [W]워커 / [P]파워 노드"

# --- General ---
MSG_EN[done]="✅ Installation complete!"
MSG_KO[done]="✅ 설치 완료!"

MSG_EN[failed]="❌ Installation failed. Check log: "
MSG_KO[failed]="❌ 설치 실패. 로그 확인: "

MSG_EN[dry_run]="🔍 DRY RUN mode — no changes will be made"
MSG_KO[dry_run]="🔍 DRY RUN 모드 — 실제 변경 없음"

MSG_EN[log_location]="Log file: "
MSG_KO[log_location]="로그 파일: "

MSG_EN[dashboard_url]="Dashboard URL: "
MSG_KO[dashboard_url]="대시보드 URL: "

MSG_EN[press_enter]="Press Enter to continue..."
MSG_KO[press_enter]="계속하려면 Enter를 누르세요..."

MSG_EN[abort]="Installation aborted."
MSG_KO[abort]="설치가 중단되었습니다."

# ---------------------------------------------------------------------------
# msg KEY — Return localized message
# ---------------------------------------------------------------------------
msg() {
    local key="$1"
    if [[ "$GIH_LANG" == "ko" ]]; then
        echo "${MSG_KO[$key]:-${MSG_EN[$key]:-[UNKNOWN:$key]}}"
    else
        echo "${MSG_EN[$key]:-[UNKNOWN:$key]}"
    fi
}

# Initialize language detection
detect_language
