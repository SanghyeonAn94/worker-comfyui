# Stage 1: Base image with common dependencies
FROM nvidia/cuda:12.6.3-cudnn-runtime-ubuntu22.04 AS base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8
# Set ComfyUI paths
ENV COMFYUI_PATH=/comfyui/custom_nodes
ENV COMFYUI_MODEL_PATH=/comfyui/models

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgl1-mesa-glx \
    software-properties-common \
    python3.10 \
    python3.10-dev \
    python3-pip

# Set Python 3.10 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1

# Upgrade pip
RUN python3 -m pip install --upgrade pip

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install uv

# Install comfy-cli
RUN uv pip install comfy-cli --system

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --version 0.3.30 --cuda-version 12.6 --nvidia

# Change working directory to ComfyUI
WORKDIR /comfyui

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Install Python runtime dependencies for the handler
RUN uv pip install runpod requests websocket-client --system

# Add application code and scripts
ADD src/start.sh handler.py test_input.json ./
RUN chmod +x /start.sh

# Create necessary directories (these will be mounted as volumes)
RUN mkdir -p /comfyui/models/checkpoints \
    /comfyui/models/vae \
    /comfyui/models/loras \
    /comfyui/models/controlnet \
    /comfyui/models/ipadapter \
    /comfyui/models/upscale_models \
    /comfyui/custom_nodes

# Install all required Python packages
RUN pip install torch torchsde einops \
    transformers>=4.49.0 safetensors>=0.3.0 \
    aiohttp accelerate pyyaml Pillow scipy tqdm psutil scikit-image \
    pillow segment_anything piexif pycocotools openmim ultralytics GitPython \
    sniffio python-dotenv lxml h11 av uvicorn anyio starlette fastapi

RUN pip install \
    diffusers \
    clip \
    pytorch-lightning \
    opencv-python \
    ftfy \
    numba \
    omegaconf \
    pytorch-wavelets \
    hfutils

RUN pip uninstall onnxruntime -y
RUN pip install onnxruntime-gpu --extra-index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/
RUN pip install aiojobs hfutils
RUN pip install insightface
RUN pip install numpy==1.24.4 numba fairscale \
    git+https://github.com/WASasquatch/img2texture \
    git+https://github.com/WASasquatch/cstr \
    git+https://github.com/WASasquatch/ffmpy \
    gitpython imageio joblib matplotlib
RUN pip install deepdiff psutil
RUN pip install pynvml==11.5.0 
RUN pip install omegaconf pytorch_lightning open_clip_torch openai-clip fsspec kornia
RUN pip install spandrel
RUN pip install --upgrade "numpy>=1.24"

RUN python /comfyui/custom_nodes/ComfyUI-Impact-Pack/install.py
RUN pip install -r /comfyui/custom_nodes/LCM_Inpaint_Outpaint_Comfy/requirements.txt