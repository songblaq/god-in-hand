#!/usr/bin/env bats
# ============================================================================
# Characterization tests for lib/models.sh
# Documents existing behavior of model recommendation and info retrieval
# ============================================================================

setup() {
    load "../helpers/setup"
    load "../helpers/mocks"
    setup_temp_dir

    # Pre-set GIH_LANG so i18n auto-detect does not interfere
    export GIH_LANG="en"
    source_lib "detect.sh"
    source_lib "models.sh"
}

teardown() {
    restore_mocks
    teardown_temp_dir
}

# ---------------------------------------------------------------------------
# recommend_models — RAM-based model selection
# ---------------------------------------------------------------------------

@test "characterize_models_recommend_16gb: power node gets large models" {
    run recommend_models 16
    assert_success
    assert_output "gemma4-e4b-q4 qwen3.5-35b-a3b-q4 qwen3-4b-q4 qwen3-0.6b-q8"
}

@test "characterize_models_recommend_20gb: 20GB also gets power node models" {
    run recommend_models 20
    assert_success
    assert_output "gemma4-e4b-q4 qwen3.5-35b-a3b-q4 qwen3-4b-q4 qwen3-0.6b-q8"
}

@test "characterize_models_recommend_12gb: hub gets E2B + qwen4b + routing" {
    run recommend_models 12
    assert_success
    assert_output "gemma4-e2b-q4 qwen3-4b-q4 qwen3-0.6b-q8"
}

@test "characterize_models_recommend_14gb: 14GB gets hub-tier models" {
    run recommend_models 14
    assert_success
    assert_output "gemma4-e2b-q4 qwen3-4b-q4 qwen3-0.6b-q8"
}

@test "characterize_models_recommend_8gb: worker gets text models" {
    run recommend_models 8
    assert_success
    assert_output "qwen3-4b-q4 qwen3-1.7b-q4 qwen3-0.6b-q8"
}

@test "characterize_models_recommend_10gb: 10GB gets worker models" {
    run recommend_models 10
    assert_success
    assert_output "qwen3-4b-q4 qwen3-1.7b-q4 qwen3-0.6b-q8"
}

@test "characterize_models_recommend_6gb: light worker gets small text" {
    run recommend_models 6
    assert_success
    assert_output "qwen3-4b-q4 qwen3-0.6b-q8"
}

@test "characterize_models_recommend_4gb: minimal worker" {
    run recommend_models 4
    assert_success
    assert_output "qwen3-1.7b-q4 qwen3-0.6b-q8"
}

@test "characterize_models_recommend_3gb: minimal gets only routing model" {
    run recommend_models 3
    assert_success
    assert_output "qwen3-0.6b-q8"
}

@test "characterize_models_recommend_default: no arg defaults to 8GB tier" {
    run recommend_models
    assert_success
    assert_output "qwen3-4b-q4 qwen3-1.7b-q4 qwen3-0.6b-q8"
}

@test "characterize_models_recommend_12gb_contains_gemma4: gemma4 in 12GB+" {
    local result
    result=$(recommend_models 12)
    [[ "$result" == *"gemma4"* ]]
}

# ---------------------------------------------------------------------------
# get_model_info — JSON parsing from config/models.json
# ---------------------------------------------------------------------------

@test "characterize_models_get_info_gemma4_e2b: retrieves correct model info" {
    if ! command -v python3 &>/dev/null; then
        skip "python3 not available"
    fi
    get_model_info "gemma4-e2b-q4"
    [[ "$MODEL_NAME" == "Gemma 4 E2B" ]]
    [[ "$MODEL_RAM" == "1.5" ]]
    [[ "$MODEL_OLLAMA_TAG" == "gemma4:e2b" ]]
}

@test "characterize_models_get_info_qwen3_06b: retrieves routing model info" {
    if ! command -v python3 &>/dev/null; then
        skip "python3 not available"
    fi
    get_model_info "qwen3-0.6b-q8"
    [[ "$MODEL_NAME" == "Qwen3 0.6B" ]]
    [[ "$MODEL_RAM" == "0.5" ]]
    [[ "$MODEL_OLLAMA_TAG" == "qwen3:0.6b" ]]
}

@test "characterize_models_get_info_gemma4_e4b: retrieves primary model info" {
    if ! command -v python3 &>/dev/null; then
        skip "python3 not available"
    fi
    get_model_info "gemma4-e4b-q4"
    [[ "$MODEL_NAME" == "Gemma 4 E4B" ]]
    [[ "$MODEL_RAM" == "5.0" ]]
    [[ "$MODEL_OLLAMA_TAG" == "gemma4:e4b" ]]
}

@test "characterize_models_get_info_returns_0_on_found" {
    run get_model_info "gemma4-e2b-q4"
    assert_success
}

@test "characterize_models_get_info_returns_1_on_not_found" {
    run get_model_info "nonexistent-model-xyz"
    assert_failure
}

@test "characterize_models_get_info_qwen35_moe: retrieves MoE model info" {
    if ! command -v python3 &>/dev/null; then
        skip "python3 not available"
    fi
    get_model_info "qwen3.5-35b-a3b-q4"
    [[ "$MODEL_NAME" == "Qwen3.5 35B-A3B MoE" ]]
    [[ "$MODEL_RAM" == "4.0" ]]
    [[ "$MODEL_OLLAMA_TAG" == "qwen3.5:35b-a3b" ]]
}

@test "characterize_models_get_info_hf_fields: HF repo and file populated" {
    if ! command -v python3 &>/dev/null; then
        skip "python3 not available"
    fi
    get_model_info "gemma4-e2b-q4"
    [[ "$MODEL_HF_REPO" == "unsloth/gemma-4-E2B-it-GGUF" ]]
    [[ "$MODEL_HF_FILE" == "gemma-4-E2B-it-Q4_K_M.gguf" ]]
}

# ---------------------------------------------------------------------------
# print_model_recommendation — Display recommended models
# ---------------------------------------------------------------------------

@test "characterize_models_print_recommendation_8gb: displays model list" {
    run print_model_recommendation 8
    assert_success
    assert_output --partial "Recommended Models"
    assert_output --partial "8GB RAM"
}

@test "characterize_models_print_recommendation_8gb: shows primary tag" {
    run print_model_recommendation 8
    assert_success
    assert_output --partial "[primary]"
}

@test "characterize_models_print_recommendation_8gb: shows router tag" {
    run print_model_recommendation 8
    assert_success
    assert_output --partial "[router]"
}

@test "characterize_models_print_recommendation_14gb: shows power tier models" {
    run print_model_recommendation 14
    assert_success
    assert_output --partial "Recommended Models"
    assert_output --partial "14GB RAM"
    assert_output --partial "ollama pull"
}

@test "characterize_models_print_recommendation_3gb: shows minimal tier" {
    run print_model_recommendation 3
    assert_success
    assert_output --partial "Qwen3 0.6B"
}

# ---------------------------------------------------------------------------
# list_loaded_models — List models in Ollama
# ---------------------------------------------------------------------------

@test "characterize_models_list_loaded: shows ollama list output" {
    mock_ollama "0.27.0"
    run list_loaded_models
    assert_success
    assert_output --partial "Loaded models:"
    assert_output --partial "NAME"
}

@test "characterize_models_list_loaded: shows not running when ollama fails" {
    local bin_dir="${TEST_TEMP_DIR}/bin"
    mkdir -p "$bin_dir"
    cat > "${bin_dir}/ollama" << 'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "list" ]]; then
    echo "Error: could not connect" >&2
    return 1
fi
SCRIPT
    chmod +x "${bin_dir}/ollama"
    export PATH="${bin_dir}:${PATH}"

    run list_loaded_models
    assert_success
    assert_output --partial "Loaded models:"
}
