#!/bin/bash

# ====================================
# 🧳 Hugging Face API 키 (필요 입력)
# ====================================
HUGGINGFACE_TOKEN="Hugging_FACE_Token_KEY"

# ====================================
# 🛠️ 사용자 설정값
# ====================================
MAX_PARALLEL=10

# ====================================
# 📂 파일 설정
# ====================================
INPUT_FILE="aria2_downloads.txt"
LOG_FILE="aria2_log.txt"
RESULT_FILE="aria2_result.txt"

# ====================================
# ⏱️ 타이머 시작
# ====================================
start_time=$(date +%s)

# ====================================
# 📦 Aria2 설치 확인
# ====================================
if ! command -v aria2c &> /dev/null; then
    echo "📦 aria2c가 설치되지 않았습니다. 설치를 시작합니다..."
    sudo apt update && sudo apt install -y aria2
    if [ $? -ne 0 ]; then
        echo "❌ aria2 설치 실패. 수동 설치 필요."
        exit 1
    fi
else
    echo "✅ aria2c 설치 확인 완료."
fi

# ====================================
# 🔐 사전 토큰 유효성 검사
# ====================================
TEST_URL="https://huggingface.co/black-forest-labs/FLUX.1-Fill-dev/resolve/main/flux1-fill-dev.safetensors"
echo "🔍 Hugging Face API 키 유효성 검사 중..."

test_response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $HUGGINGFACE_TOKEN" "$TEST_URL")

if [[ "$test_response" == "403" || "$test_response" == "401" ]]; then
    echo -e "\n\033[0;31m🚫 오류: Hugging Face API 키가 유효하지 않습니다! (에러코드: $test_response)\033[0m"
    echo "# 🚫 잘못된 Hugging Face API 키 검지됨 (에러 $test_response)" | tee -a "$RESULT_FILE"
    echo "# 5초 대기 후, 인증 없이 받을 수 있는 파일들부터 다운로드를 시작합니다..." | tee -a "$RESULT_FILE"
    sleep 5
else
    echo "✅ Hugging Face API 키 인증 성공 ($test_response)"
fi

# ====================================
# 📌 다운로드 리스트
# ====================================
downloads=(
  "https://huggingface.co/stable-diffusion-v1-5/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors|/workspace/ComfyUI/models/checkpoints/v1-5-pruned-emaonly.safetensors"
  "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors|/workspace/ComfyUI/models/text_encoders/clip_l.safetensors"
  "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors|/workspace/ComfyUI/models/text_encoders/t5xxl_fp8_e4m3fn.safetensors"
  "https://huggingface.co/Comfy-Org/sigclip_vision_384/resolve/main/sigclip_vision_patch14_384.safetensors|/workspace/ComfyUI/models/clip_vision/sigclip_vision_patch14_384.safetensors"
  "https://huggingface.co/SporkySporkness/FLUX.1-Fill-dev-GGUF/resolve/main/flux1-fill-dev-fp16-Q4_0-GGUF.gguf|/workspace/ComfyUI/models/unet/GGUF/Inpaint/flux1-fill-dev-fp16-Q4_0-GGUF.gguf"
  "https://huggingface.co/SporkySporkness/FLUX.1-Fill-dev-GGUF/resolve/main/flux1-fill-dev-fp16-Q5_0-GGUF.gguf|/workspace/ComfyUI/models/unet/GGUF/Inpaint/flux1-fill-dev-fp16-Q5_0-GGUF.gguf"
  "https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf/resolve/main/t5-v1_1-xxl-encoder-Q5_K_M.gguf|/workspace/ComfyUI/models/text_encoders/GGUF-t5/t5-v1_1-xxl-encoder-Q5_K_M.gguf"
  "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.1.safetensors|/workspace/ComfyUI/models/pulid/pulid_flux_v0.9.1.safetensors"
  "https://huggingface.co/QuanSun/EVA-CLIP/resolve/main/EVA02_CLIP_L_336_psz14_s6B.pt|/workspace/ComfyUI/models/clip/EVA02_CLIP_L_336_psz14_s6B.pt"
  "https://huggingface.co/ali-vilab/ACE_Plus/resolve/main/portrait/comfyui_portrait_lora64.safetensors|/workspace/ComfyUI/models/loras/comfyui_portrait_lora64.safetensors"
  "https://huggingface.co/ali-vilab/ACE_Plus/resolve/main/subject/comfyui_subject_lora16.safetensors|/workspace/ComfyUI/models/loras/comfyui_subject_lora16.safetensors"
  "https://huggingface.co/lllyasviel/flux1-dev-bnb-nf4/resolve/main/flux1-dev-bnb-nf4-v2.safetensors|/workspace/ComfyUI/models/unet/flux1-dev-bnb-nf4-v2.safetensors"
  "https://huggingface.co/black-forest-labs/FLUX.1-Fill-dev/resolve/main/flux1-fill-dev.safetensors|/workspace/ComfyUI/models/unet/Inpaint/flux1-fill-dev.safetensors"
  "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/vae/diffusion_pytorch_model.safetensors|/workspace/ComfyUI/models/vae/diffusion_pytorch_model.safetensors"
  "https://huggingface.co/black-forest-labs/FLUX.1-Redux-dev/resolve/main/flux1-redux-dev.safetensors|/workspace/ComfyUI/models/style_models/flux1-redux-dev.safetensors"
  "https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q6_K.gguf|/workspace/ComfyUI/models/unet/flux1-dev-Q6_K.gguf"
  
)

# ====================================
# 🧹 초기화
# ====================================
rm -f "$INPUT_FILE" "$LOG_FILE" "$RESULT_FILE"

# ====================================
# 📋 리스트 생성
# ====================================
for item in "${downloads[@]}"; do
  IFS="|" read -r url path <<< "$item"
  if [ -f "$path" ]; then
    echo "[완료] 이미 존재: $path" | tee -a "$RESULT_FILE"
  else
    mkdir -p "$(dirname "$path")"
    echo "$url" >> "$INPUT_FILE"
    echo "  dir=$(dirname "$path")" >> "$INPUT_FILE"
    echo "  out=$(basename "$path")" >> "$INPUT_FILE"
  fi
done

# ====================================
# 🚀 다운로드 시작
# ====================================
if [ -s "$INPUT_FILE" ]; then
  echo -e "\n🚀 다운로드 시작...\n"
  aria2c -x 8 -j "$MAX_PARALLEL" -i "$INPUT_FILE" \
         --console-log-level=notice --summary-interval=1 \
         --header="Authorization: Bearer $HUGGINGFACE_TOKEN" \
         | tee -a "$LOG_FILE"
else
  echo "📂 다운로드할 항목이 없습니다."
fi

# ====================================
# ✅ 결과 반영
# ====================================
total=${#downloads[@]}
success=0
failures=()

for item in "${downloads[@]}"; do
  IFS="|" read -r url path <<< "$item"
  if [ -f "$path" ]; then
    echo "[완료] $path" | tee -a "$RESULT_FILE"
    ((success++))
  else
    echo "[실패] $path" | tee -a "$RESULT_FILE"
    failures+=("$path")
  fi
done

# ====================================
# ⏱️ 소요 시간
# ====================================
end_time=$(date +%s)
duration=$((end_time - start_time))
minutes=$((duration / 60))
seconds=$((duration % 60))

echo -e "\n🕒 총 소요 시간: ${minutes}분 ${seconds}초\n" | tee -a "$RESULT_FILE"

# ====================================
# 📊 참가 요약
# ====================================
if [ "$success" -eq "$total" ]; then
  echo "✅ $success/$total 모든 파일 정상!" | tee -a "$RESULT_FILE"
else
  echo "❌ $success/$total 건강, ${#failures[@]} 실패" | tee -a "$RESULT_FILE"
  echo "🔹 실패 파일 목록:" | tee -a "$RESULT_FILE"
  for fail in "${failures[@]}"; do
    echo " - $fail" | tee -a "$RESULT_FILE"
  done
fi

# ====================================
# ❌ 다중 실패 파일 처리
# ====================================
echo -e "\n🔍 다중 실패(또는 중단) 파일 검사..."
broken_files=()

for item in "${downloads[@]}"; do
  IFS="|" read -r url path <<< "$item"
  if [[ -f "$path" && ! -s "$path" ]] || [[ -f "$path.aria2" ]]; then
    broken_files+=("$path")
  fi
done

if [ "${#broken_files[@]}" -gt 0 ]; then
  echo -e "\n🚨 ${#broken_files[@]}개의 중단/잘못된 파일 검사 완료."
  for bf in "${broken_files[@]}"; do
    echo " - $bf"
  done

  echo -e "\n❓ 자동으로 삭제하고 다시 다운로드 하시겠습니까? (Y/N): \c"
  read -r confirm_retry

  if [[ "$confirm_retry" == "Y" || "$confirm_retry" == "y" ]]; then
    echo "🗑️ 삭제 중..."
    for bf in "${broken_files[@]}"; do
      rm -f "$bf" "$bf.aria2"
      echo "삭제됨: $bf"
    done
    echo "♻️ 다시 시작합니다..."
    bash "$0"
    exit 0
  else
    echo "❌ 재시도 없이 종료합니다."
    exit 0
  fi
else
  echo "✅ 모든 파일이 정상적으로 다운되었습니다."
   # ====================================
  # 🎓 AI 교육 & 커뮤니티 안내 (Community & EDU)
  # ====================================
  echo -e "\n====🎓 AI 교육 & 커뮤니티 안내====\n"
  echo -e "1. Youtube : https://www.youtube.com/@A01demort"
  echo "2. 교육 문의 : https://a01demort.com"
  echo "3. Udemy 강의 : https://bit.ly/comfyclass"
  echo "4. Stable AI KOREA : https://cafe.naver.com/sdfkorea"
  echo "5. 카카오톡 오픈채팅방 : https://open.kakao.com/o/gxvpv2Mf"
  echo "6. CIVITAI : https://civitai.com/user/a01demort"
  echo -e "\n==================================="
fi
