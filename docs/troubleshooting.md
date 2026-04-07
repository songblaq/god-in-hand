# Troubleshooting Guide

[한국어](#한국어) | English

## Installation Issues

### "Not running inside Termux"
**Cause:** The installer detected you're not in the Termux environment.
**Fix:** Install Termux from F-Droid and run the script inside it.
```
https://f-droid.org/packages/com.termux/
```

### "Termux must be installed from F-Droid"
**Cause:** The Play Store version of Termux hasn't been updated since 2020.
**Fix:**
1. Uninstall the Play Store version
2. Install F-Droid: https://f-droid.org/
3. Search "Termux" in F-Droid and install
4. Also install: Termux:API, Termux:Boot

### pkg update fails / mirror errors
**Cause:** Default Termux mirror may be unreachable.
**Fix:**
```bash
termux-change-repo
# Select a mirror close to your region
pkg update && pkg upgrade -y
```

### Node.js version too old
**Cause:** Termux may have an older Node.js cached.
**Fix:**
```bash
pkg install nodejs-lts
node --version  # Should be v22+
```

### Build errors during cmake / llama.cpp compilation
**Cause:** Missing build tools or insufficient storage.
**Fix:**
```bash
pkg install build-essential cmake clang
df -h  # Check available space (need 5GB+)
```

## Runtime Issues

### Ollama won't start / port 11434 not responding

**Check 1:** Is Ollama already running?
```bash
pgrep ollama
curl http://localhost:11434/api/version
```

**Check 2:** Kill stale process and restart
```bash
pkill -f ollama
sleep 2
ollama serve &
```

**Check 3:** Check logs
```bash
cat ~/.god-in-hand/logs/ollama.log
```

### Model download fails
**Cause:** Network issues or insufficient storage.
**Fix:**
```bash
# Check storage
df -h

# Try manual download
ollama pull gemma4:e2b

# Or download GGUF directly
curl -L -o model.gguf https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf
```

### Model loads but inference is very slow
**Cause:** Thermal throttling or insufficient RAM.
**Fix:**
1. Check temperature:
   ```bash
   cat /sys/class/thermal/thermal_zone0/temp
   # Divide by 1000 for Celsius. Above 45°C = throttling likely
   ```
2. Check RAM usage:
   ```bash
   free -m
   ```
3. Try a smaller model:
   ```bash
   ollama run qwen3:0.6b  # Instead of gemma4:e4b
   ```
4. Let the device cool down for 5-10 minutes

### OpenClaw gateway crashes on WiFi switch
**Cause:** mDNS/Bonjour module can't handle IP changes.
**Fix:**
```bash
# Restart the gateway after switching networks
openclaw stop
sleep 2
openclaw
```

**Prevention:** Use a static IP for the hub device, or connect via hostname.

### "Session lock" errors
**Cause:** Previous OpenClaw session didn't shut down cleanly.
**Fix:**
```bash
rm -f ~/.openclaw/sessions/*.lock
openclaw
```

## Samsung-Specific Issues

### Termux gets killed in background
**Cause:** Samsung One UI's aggressive battery optimization.
**Fix (ALL of these):**
1. Settings > Apps > Termux > Battery > Unrestricted
2. Settings > Battery > Background usage limits > Never sleeping apps > Add Termux
3. Settings > Device care > Battery > More battery settings > Adaptive battery > OFF
4. Settings > Apps > Termux > Remove from "Sleeping apps" and "Deep sleeping apps"

### Termux notification keeps disappearing
**Cause:** Samsung kills the foreground notification.
**Fix:**
```bash
# In Termux, acquire wake lock:
termux-wake-lock

# Install Termux:Boot for auto-start
# Create: ~/.termux/boot/start.sh
```

## Performance Optimization

### Reduce RAM usage
```bash
# Use smaller quantization
ollama pull gemma4:e2b  # Q4 is the default, smallest practical

# Reduce context window
# In ollama Modelfile:
PARAMETER num_ctx 4096  # Instead of default 131072

# Unload unused models
ollama stop gemma4:e4b
```

### Manage thermal throttling
```bash
# Monitor temperature
watch -n 5 'cat /sys/class/thermal/thermal_zone0/temp'

# Add cooldown between heavy requests
# The hub dashboard monitors temperature automatically
```

### Save battery on worker nodes
```bash
# Use the lightest possible model for background tasks
ollama pull qwen3:0.6b

# Schedule heavy tasks during charging
# Use Termux:API to check battery:
termux-battery-status | grep percentage
```

## Diagnostics

### Run full health check
```bash
bash ~/.god-in-hand/repo/lib/health.sh
```

### Generate status JSON (for hub dashboard)
```bash
source ~/.god-in-hand/repo/lib/health.sh
generate_status_json
```

### Check OpenClaw health
```bash
openclaw doctor
```

### View install log
```bash
ls -la ~/.god-in-hand/logs/
cat ~/.god-in-hand/logs/install-*.log
```

## Getting Help

- OpenClaw community Discord: #android channel
- Project issues: https://github.com/songblaq/god-in-hand/issues
- OpenClaw docs: https://docs.openclaw.com

---

# 한국어

## 설치 문제

### "Termux 안에서 실행되지 않음"
F-Droid에서 Termux를 설치하고 그 안에서 스크립트를 실행하세요.
```
https://f-droid.org/packages/com.termux/
```

### pkg update 실패 / 미러 에러
```bash
termux-change-repo  # 가까운 미러 선택
pkg update && pkg upgrade -y
```

### Ollama가 시작되지 않음
```bash
pkill -f ollama
sleep 2
ollama serve &
curl http://localhost:11434/api/version
```

## 삼성 디바이스 문제

### Termux가 백그라운드에서 종료됨
다음을 **모두** 설정하세요:
1. 설정 > 앱 > Termux > 배터리 > 제한 없음
2. 설정 > 배터리 > 백그라운드 사용 제한 > 절전 제외 앱 > Termux 추가
3. 설정 > 디바이스 케어 > 배터리 > 추가 배터리 설정 > 자동 조절 배터리 > 끄기
4. 설정 > 앱 > Termux > "절전 중인 앱"과 "딥 슬립 앱"에서 제거

## 진단

```bash
# 전체 헬스 체크
bash ~/.god-in-hand/repo/lib/health.sh

# OpenClaw 진단
openclaw doctor

# 설치 로그 확인
cat ~/.god-in-hand/logs/install-*.log
```
