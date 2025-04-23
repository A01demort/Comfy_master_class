#!/bin/bash

ERROR_LOG="/tmp/comfyui_import_loop.log"
FINAL_LOG="/workspace/ComfyUI/scripts/fast_import_fix_loop.log"
TEMP_MODULES="/tmp/missing_modules.txt"
INSTALLED_MODULES="/workspace/ComfyUI/requirements_persist.txt"

#몇 번 검토할 것인지? + 1회 기간은 몇 초를 줄 것인지?
MAX_ITER=20
SLEEP_TIME=10

mkdir -p /workspace/ComfyUI/scripts

echo -e "\n🚀 ImportError 자동 복구 + RunPod 재시작 대응 스크립트 시작" | tee "$FINAL_LOG"

# 복구 모드: RunPod 재시작 후 모듈 재설치
if [ "$1" = "restore" ]; then
    echo "🔁 복구 모드: 저장된 pip 패키지 설치 중..." | tee -a "$FINAL_LOG"
    if [ -s "$INSTALLED_MODULES" ]; then
        pip install -r "$INSTALLED_MODULES" >> "$FINAL_LOG" 2>&1 || echo "⚠️ 일부 설치 실패" | tee -a "$FINAL_LOG"
    else
        echo "📂 복구 목록 없음. 스킵." | tee -a "$FINAL_LOG"
    fi
    echo "✅ 복구 완료" | tee -a "$FINAL_LOG"
    exit 0
fi

> "$TEMP_MODULES"
touch "$INSTALLED_MODULES"

# 이름 매핑 사전 정의
declare -A MODULE_MAP=(
    [cv2]="opencv-python"
    [PIL]="Pillow"
    [open_clip]="open_clip_torch"
)

for ((i=1; i<=MAX_ITER; i++)); do
    echo -e "\n🔁 [$i/$MAX_ITER] ComfyUI 실행 (대기 ${SLEEP_TIME}s)..." | tee -a "$FINAL_LOG"

    > "$ERROR_LOG"
    python /workspace/ComfyUI/main.py --listen 0.0.0.0 --port=8188 \
    --front-end-version Comfy-Org/ComfyUI_frontend@latest > "$ERROR_LOG" 2>&1 &

    COMFY_PID=$!
    sleep $SLEEP_TIME

    if ps -p $COMFY_PID > /dev/null; then
        kill $COMFY_PID
        echo "🛑 comfyui 종료됨 (PID $COMFY_PID)" | tee -a "$FINAL_LOG"
    else
        echo "⚠️ comfyui 프로세스 조기 종료됨 (PID $COMFY_PID 없음)" | tee -a "$FINAL_LOG"
    fi

    grep -E "No module named|ImportError" "$ERROR_LOG" \
    | grep -oP "'\K[^']+" | sort | uniq > "$TEMP_MODULES"

    if [ ! -s "$TEMP_MODULES" ]; then
        echo "✅ 설치할 모듈 없음. 루프 종료." | tee -a "$FINAL_LOG"
        break
    fi

    mapfile -t MODULE_LIST < <(sort "$TEMP_MODULES" | uniq)
    SKIP_COUNT=0
    INSTALL_COUNT=0

    for MOD in "${MODULE_LIST[@]}"; do
        if grep -q "^$MOD$" "$INSTALLED_MODULES"; then
            echo "⏩ $MOD (이미 설치됨으로 인식됨) — 스킵" | tee -a "$FINAL_LOG"
            ((SKIP_COUNT++))
            continue
        fi

        # 모듈 이름 매핑 적용
        PKG=${MODULE_MAP[$MOD]:-$MOD}

        echo -e "➡️ [설치 시도 중] pip install $PKG (from import '$MOD')" | tee -a "$FINAL_LOG"
        pip install "$PKG" >> "$FINAL_LOG" 2>&1
        if [ $? -eq 0 ]; then
            echo "$MOD" >> "$INSTALLED_MODULES"
            echo "✅ 설치 성공: $PKG (import '$MOD')" | tee -a "$FINAL_LOG"
            ((INSTALL_COUNT++))
        else
            echo "❌ 설치 실패: $PKG (import '$MOD')" | tee -a "$FINAL_LOG"
            echo "⛔ 설치 실패한 모듈은 기록하지 않음 (재탐지 예정)" | tee -a "$FINAL_LOG"
        fi
    done

    echo "📊 라운드 $i 완료: $INSTALL_COUNT개 설치, $SKIP_COUNT개 스킵" | tee -a "$FINAL_LOG"

    if [ "$INSTALL_COUNT" -eq 0 ]; then
        echo "✅ 추가 설치 없음. 종료 조건 충족." | tee -a "$FINAL_LOG"
        break
    fi

done

echo -e "\n🎯 설치 루프 완료. 전체 로그: $FINAL_LOG"

# ✅ AI는 A1
cat <<EOF | tee -a "$FINAL_LOG"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎓 AI 교육 & 커뮤니티 안내

📩 교육 문의 : https://a01demort.com
🎓 Udemy 강의 : https://bit.ly/comfyclass
📺 A1 (AI는 에이원) 유튜브 : https://www.youtube.com/@A01demort
☕ 스테이블 AI 코리아 네이버 카페 : https://cafe.naver.com/sdfkorea
🖼️ Civitai 프로필 : https://civitai.com/user/a01demort
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
