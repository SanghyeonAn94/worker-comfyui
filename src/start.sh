#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# Install and verify custom nodes
echo 'Listing contents of /comfyui/custom_nodes:' && ls -la /comfyui/custom_nodes/ &&
echo 'Checking if ComfyUI-Impact-Pack/install.py exists:' && ls -la /comfyui/custom_nodes/ComfyUI-Impact-Pack/install.py &&
echo 'Checking if LCM_Inpaint_Outpaint_Comfy/requirements.txt exists:' && ls -la /comfyui/custom_nodes/LCM_Inpaint_Outpaint_Comfy/requirements.txt
python /comfyui/custom_nodes/ComfyUI-Impact-Pack/install.py
# 시스템 패키지로 설치된 blinker가 있으면 삭제
if dpkg -l | grep -q python3-blinker; then
    echo "Removing system-installed python3-blinker..."
    apt-get remove -y python3-blinker
fi
pip install --upgrade blinker pyparsing
pip install -r /comfyui/custom_nodes/LCM_Inpaint_Outpaint_Comfy/requirements.txt

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    echo "worker-comfyui: Starting ComfyUI"
    python /comfyui/main.py --disable-auto-launch --disable-metadata --listen &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    echo "worker-comfyui: Starting ComfyUI"
    python /comfyui/main.py --disable-auto-launch --disable-metadata &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py
fi