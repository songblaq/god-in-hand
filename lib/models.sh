#!/usr/bin/env bash
# ============================================================================
# God in Hand — Model Management Module
# RAM-based model recommendation, download, and verification
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_JSON="${SCRIPT_DIR}/../config/models.json"
GIH_MODEL_DIR="${HOME}/.god-in-hand/models"

# ---------------------------------------------------------------------------
# recommend_models — Select best models based on available RAM
# Args: $1 = total RAM in GB
# Outputs: space-separated list of model IDs
# ---------------------------------------------------------------------------
recommend_models() {
    local ram_gb="${1:-8}"
    local models=""

    if [[ $ram_gb -ge 14 ]]; then
        # Power node: primary large model + routing model
        models="gemma4-e4b-q4 qwen3.5-35b-a3b-q4 qwen3-0.6b-q8"
    elif [[ $ram_gb -ge 10 ]]; then
        # Hub: main reasoning + routing
        models="gemma4-e4b-q4 qwen3-0.6b-q8"
    elif [[ $ram_gb -ge 6 ]]; then
        # Worker with decent RAM
        models="gemma4-e2b-q4 qwen3-4b-q4 qwen3-0.6b-q8"
    elif [[ $ram_gb -ge 4 ]]; then
        # Tight worker
        models="gemma4-e2b-q4 qwen3-0.6b-q8"
    else
        # Minimal
        models="qwen3-0.6b-q8"
    fi

    echo "$models"
}

# ---------------------------------------------------------------------------
# get_model_info — Extract info from models.json for a given model ID
# Args: $1 = model ID
# Sets: MODEL_NAME, MODEL_RAM, MODEL_OLLAMA_TAG, MODEL_HF_REPO, MODEL_HF_FILE
# Returns: 0 = found, 1 = not found
# ---------------------------------------------------------------------------
get_model_info() {
    local model_id="$1"
    MODEL_NAME=""
    MODEL_RAM=""
    MODEL_OLLAMA_TAG=""
    MODEL_HF_REPO=""
    MODEL_HF_FILE=""

    if [[ ! -f "$MODELS_JSON" ]]; then
        return 1
    fi

    # Use python for JSON parsing if available, else use grep heuristics
    if command -v python3 &>/dev/null; then
        local info
        info=$(python3 -c "
import json, sys
with open('${MODELS_JSON}') as f:
    data = json.load(f)
for m in data['models']:
    if m['id'] == '${model_id}':
        print(m.get('name',''))
        print(m.get('ram_required_gb',''))
        print(m.get('ollama_tag',''))
        print(m.get('hf_repo',''))
        print(m.get('hf_file',''))
        sys.exit(0)
sys.exit(1)
" 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            MODEL_NAME=$(echo "$info" | sed -n '1p')
            MODEL_RAM=$(echo "$info" | sed -n '2p')
            MODEL_OLLAMA_TAG=$(echo "$info" | sed -n '3p')
            MODEL_HF_REPO=$(echo "$info" | sed -n '4p')
            MODEL_HF_FILE=$(echo "$info" | sed -n '5p')
            return 0
        fi
    else
        # Fallback: grep-based parsing (less reliable but works without python)
        if grep -q "\"$model_id\"" "$MODELS_JSON"; then
            MODEL_NAME=$(grep -A2 "\"$model_id\"" "$MODELS_JSON" | grep '"name"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
            MODEL_OLLAMA_TAG=$(grep -A20 "\"$model_id\"" "$MODELS_JSON" | grep '"ollama_tag"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
            return 0
        fi
    fi

    return 1
}

# ---------------------------------------------------------------------------
# print_model_recommendation — Display recommended models for this device
# Args: $1 = total RAM in GB
# ---------------------------------------------------------------------------
print_model_recommendation() {
    local ram_gb="${1:-8}"
    local recommended
    recommended=$(recommend_models "$ram_gb")

    echo ""
    echo -e "${BOLD}🧠 Recommended Models (${ram_gb}GB RAM)${NC}"
    echo "────────────────────────────────────────────"

    local idx=1
    for model_id in $recommended; do
        if get_model_info "$model_id"; then
            local role_tag=""
            if [[ $idx -eq 1 ]]; then
                role_tag=" ${GREEN}[primary]${NC}"
            elif [[ "$model_id" == *"0.6b"* ]]; then
                role_tag=" ${BLUE}[router]${NC}"
            fi
            echo -e "  ${idx}) ${CYAN}${MODEL_NAME}${NC} — ${MODEL_RAM}GB RAM${role_tag}"
            if [[ -n "$MODEL_OLLAMA_TAG" ]]; then
                echo -e "     ollama pull ${MODEL_OLLAMA_TAG}"
            fi
        else
            echo -e "  ${idx}) ${model_id} (info not found)"
        fi
        ((idx++))
    done
    echo "────────────────────────────────────────────"
}

# ---------------------------------------------------------------------------
# download_model_ollama — Download model via Ollama
# Args: $1 = ollama tag (e.g., "gemma4:e2b")
# Returns: 0 = success, 1 = failure
# ---------------------------------------------------------------------------
download_model_ollama() {
    local tag="$1"

    if [[ -z "$tag" ]]; then
        echo "ERROR: No ollama tag specified"
        return 1
    fi

    # Check if Ollama is running
    if ! curl -sf "http://localhost:11434/api/version" >/dev/null 2>&1; then
        echo "Starting Ollama server..."
        ollama serve &>/dev/null &
        local ollama_pid=$!
        sleep 3

        if ! curl -sf "http://localhost:11434/api/version" >/dev/null 2>&1; then
            echo "ERROR: Failed to start Ollama server"
            return 1
        fi
    fi

    echo "Downloading model: ${tag}..."
    if ollama pull "$tag" 2>&1; then
        echo "Model ${tag} downloaded successfully"
        return 0
    else
        echo "ERROR: Failed to download model ${tag}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# download_model_hf — Download model from HuggingFace (GGUF)
# Args: $1 = hf repo, $2 = filename
# Returns: 0 = success, 1 = failure
# ---------------------------------------------------------------------------
download_model_hf() {
    local repo="$1"
    local filename="$2"

    if [[ -z "$repo" || -z "$filename" ]]; then
        echo "ERROR: HF repo and filename required"
        return 1
    fi

    mkdir -p "$GIH_MODEL_DIR"
    local output_path="${GIH_MODEL_DIR}/${filename}"

    # Skip if already downloaded
    if [[ -f "$output_path" ]]; then
        echo "Model already exists: ${output_path}"
        return 0
    fi

    # Method 1: huggingface-cli
    if command -v huggingface-cli &>/dev/null; then
        echo "Downloading via huggingface-cli..."
        if huggingface-cli download "$repo" "$filename" --local-dir "$GIH_MODEL_DIR" 2>&1; then
            return 0
        fi
    fi

    # Method 2: curl direct download
    local url="https://huggingface.co/${repo}/resolve/main/${filename}"
    echo "Downloading: ${url}"
    echo "Destination: ${output_path}"

    if curl -L --progress-bar -o "$output_path" "$url" 2>&1; then
        # Verify file is not an error page
        local file_size
        file_size=$(stat -f%z "$output_path" 2>/dev/null || stat -c%s "$output_path" 2>/dev/null || echo "0")
        if [[ $file_size -lt 1000000 ]]; then
            echo "ERROR: Downloaded file too small (${file_size} bytes). Likely an error."
            rm -f "$output_path"
            return 1
        fi
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# install_models — Interactive model installation flow
# Args: $1 = total RAM in GB, $2 = serving engine ("ollama" or "llamacpp")
# ---------------------------------------------------------------------------
install_models() {
    local ram_gb="${1:-8}"
    local engine="${2:-ollama}"
    local recommended
    recommended=$(recommend_models "$ram_gb")

    print_model_recommendation "$ram_gb"

    echo ""
    echo "Install recommended models? [Y/n/custom]"
    read -r choice

    case "${choice,,}" in
        n|no)
            echo "Skipping model installation. You can install later with:"
            echo "  ollama pull <model_tag>"
            return 0
            ;;
        c|custom)
            echo "Enter model IDs (space-separated):"
            echo "Available: gemma4-e2b-q4 gemma4-e4b-q4 qwen3-0.6b-q8 qwen3-1.7b-q4 qwen3-4b-q4 qwen3.5-35b-a3b-q4 llama3.2-1b-q4 llama3.2-3b-q4 phi4-mini-q4"
            read -r custom_models
            recommended="$custom_models"
            ;;
    esac

    local success_count=0
    local fail_count=0

    for model_id in $recommended; do
        if get_model_info "$model_id"; then
            echo ""
            echo -e "📦 Installing ${BOLD}${MODEL_NAME}${NC}..."

            if [[ "$engine" == "ollama" && -n "$MODEL_OLLAMA_TAG" ]]; then
                if download_model_ollama "$MODEL_OLLAMA_TAG"; then
                    ((success_count++))
                else
                    ((fail_count++))
                fi
            elif [[ -n "$MODEL_HF_REPO" && -n "$MODEL_HF_FILE" ]]; then
                if download_model_hf "$MODEL_HF_REPO" "$MODEL_HF_FILE"; then
                    ((success_count++))
                else
                    ((fail_count++))
                fi
            else
                echo "WARN: No download method available for ${model_id}"
                ((fail_count++))
            fi
        fi
    done

    echo ""
    echo -e "Model installation: ${GREEN}${success_count} succeeded${NC}, ${RED}${fail_count} failed${NC}"
    return $fail_count
}

# ---------------------------------------------------------------------------
# test_model_inference — Quick smoke test for a loaded model
# Args: $1 = api_base (default: http://localhost:11434)
# Returns: 0 = working, 1 = failed
# ---------------------------------------------------------------------------
test_model_inference() {
    local api_base="${1:-http://localhost:11434}"
    local endpoint="${api_base}/v1/chat/completions"

    echo "Testing inference at ${endpoint}..."

    local response
    response=$(curl -sf --max-time 30 "$endpoint" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "default",
            "messages": [{"role": "user", "content": "Say hello in exactly 3 words."}],
            "max_tokens": 20,
            "temperature": 0.1
        }' 2>/dev/null)

    if [[ $? -eq 0 && -n "$response" ]]; then
        local content
        content=$(echo "$response" | grep -oE '"content"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
        if [[ -n "$content" ]]; then
            echo "Response: ${content}"
            return 0
        fi
    fi

    return 1
}

# ---------------------------------------------------------------------------
# list_loaded_models — List models currently loaded in Ollama
# ---------------------------------------------------------------------------
list_loaded_models() {
    if command -v ollama &>/dev/null; then
        echo "Loaded models:"
        ollama list 2>/dev/null || echo "  (Ollama not running)"
    fi
}
