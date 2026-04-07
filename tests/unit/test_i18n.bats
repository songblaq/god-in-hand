#!/usr/bin/env bats
# ============================================================================
# Characterization tests for lib/i18n.sh
# Documents existing behavior of detect_language() and msg()
# ============================================================================

setup() {
    load "../helpers/setup"
    load "../helpers/mocks"
    setup_temp_dir

    # Reset GIH_LANG before each test so detect_language can be re-invoked
    GIH_LANG=""

    # Source i18n without triggering detect_language auto-run
    # We do this by pre-setting GIH_LANG so the auto-detect returns early
    GIH_LANG="en"
    source "${PROJECT_ROOT}/lib/i18n.sh"
}

teardown() {
    restore_mocks
    teardown_temp_dir
}

# ---------------------------------------------------------------------------
# msg() — English messages
# ---------------------------------------------------------------------------

@test "characterize_i18n_msg_welcome_en: returns English welcome string" {
    GIH_LANG="en"
    run msg "welcome"
    assert_success
    assert_output "🤲 God in Hand — On-device AI Agent Installer"
}

@test "characterize_i18n_msg_phase0_en: returns English phase0 string" {
    GIH_LANG="en"
    run msg "phase0"
    assert_success
    assert_output "Phase 0: Pre-flight Checks"
}

@test "characterize_i18n_msg_check_termux_en: returns Termux check message" {
    GIH_LANG="en"
    run msg "check_termux"
    assert_success
    assert_output "Checking Termux version..."
}

@test "characterize_i18n_msg_check_ram_ok_en: returns RAM OK message" {
    GIH_LANG="en"
    run msg "check_ram_ok"
    assert_success
    assert_output "RAM OK"
}

@test "characterize_i18n_msg_check_storage_fail_en: returns storage fail message" {
    GIH_LANG="en"
    run msg "check_storage_fail"
    assert_success
    assert_output "At least 10GB free storage required. Available: "
}

@test "characterize_i18n_msg_done_en: returns installation complete message" {
    GIH_LANG="en"
    run msg "done"
    assert_success
    assert_output "✅ Installation complete!"
}

@test "characterize_i18n_msg_failed_en: returns installation failed message" {
    GIH_LANG="en"
    run msg "failed"
    assert_success
    assert_output "❌ Installation failed. Check log: "
}

@test "characterize_i18n_msg_dry_run_en: returns dry run message" {
    GIH_LANG="en"
    run msg "dry_run"
    assert_success
    assert_output "🔍 DRY RUN mode — no changes will be made"
}

@test "characterize_i18n_msg_unknown_key_en: unknown key echoes key itself" {
    GIH_LANG="en"
    run msg "nonexistent_key_xyz"
    assert_success
    assert_output "nonexistent_key_xyz"
}

@test "characterize_i18n_msg_abort_en: returns abort message" {
    GIH_LANG="en"
    run msg "abort"
    assert_success
    assert_output "Installation aborted."
}

@test "characterize_i18n_msg_phase1_en: returns phase1 message" {
    GIH_LANG="en"
    run msg "phase1"
    assert_success
    assert_output "Phase 1: Checking Existing Installations"
}

@test "characterize_i18n_msg_phase3_en: returns phase3 message" {
    GIH_LANG="en"
    run msg "phase3"
    assert_success
    assert_output "Phase 3: Installing Core Components"
}

# ---------------------------------------------------------------------------
# msg() — Korean messages
# ---------------------------------------------------------------------------

@test "characterize_i18n_msg_welcome_ko: returns Korean welcome string" {
    GIH_LANG="ko"
    run msg "welcome"
    assert_success
    assert_output "🤲 손 안의 신 — 온디바이스 AI 에이전트 설치기"
}

@test "characterize_i18n_msg_phase0_ko: returns Korean phase0 string" {
    GIH_LANG="ko"
    run msg "phase0"
    assert_success
    assert_output "Phase 0: 사전 점검"
}

@test "characterize_i18n_msg_done_ko: returns Korean done string" {
    GIH_LANG="ko"
    run msg "done"
    assert_success
    assert_output "✅ 설치 완료!"
}

@test "characterize_i18n_msg_check_ram_warn_ko: returns Korean RAM warning" {
    GIH_LANG="ko"
    run msg "check_ram_warn"
    assert_success
    assert_output "사용 가능 RAM이 4GB 미만입니다. 경량 모델만 사용 가능합니다."
}

@test "characterize_i18n_msg_unknown_key_ko: unknown key echoes key itself in ko mode" {
    GIH_LANG="ko"
    run msg "nonexistent_key_xyz"
    assert_success
    assert_output "nonexistent_key_xyz"
}

# ---------------------------------------------------------------------------
# detect_language() — Language detection logic
# ---------------------------------------------------------------------------

@test "characterize_i18n_detect_language_prefers_existing_gih_lang" {
    GIH_LANG="ko"
    detect_language
    [[ "$GIH_LANG" == "ko" ]]
}

@test "characterize_i18n_detect_language_from_LANG_env_korean" {
    GIH_LANG=""
    # Ensure getprop is not available
    unset -f getprop 2>/dev/null
    LANG="ko_KR.UTF-8"
    detect_language
    [[ "$GIH_LANG" == "ko" ]]
}

@test "characterize_i18n_detect_language_from_LANG_env_english" {
    GIH_LANG=""
    unset -f getprop 2>/dev/null
    LANG="en_US.UTF-8"
    detect_language
    [[ "$GIH_LANG" == "en" ]]
}

@test "characterize_i18n_detect_language_defaults_to_en" {
    GIH_LANG=""
    unset -f getprop 2>/dev/null
    unset LANG
    unset LC_ALL
    unset LC_MESSAGES
    detect_language
    [[ "$GIH_LANG" == "en" ]]
}
