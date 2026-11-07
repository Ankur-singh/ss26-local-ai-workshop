# syntax=docker/dockerfile:1
# The sandbox every engine runs in: CUDA 12.8 (nvcc for mini-sglang's JIT kernels), Python 3.12 with mini-sglang's
# pinned dependencies, and the omp coding agent pointed at the local SGLang server. No git and no pip.
FROM nvidia/cuda:12.8.1-devel-ubuntu24.04

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      python3.12 python3.12-dev python3.12-venv build-essential ninja-build libnuma1 \
      curl ca-certificates procps psmisc less jq ripgrep vim-tiny \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt
RUN --mount=from=ghcr.io/astral-sh/uv:0.13.6,source=/uv,target=/usr/local/bin/uv \
    UV_NO_CACHE=1 uv venv -q --python /usr/bin/python3.12 /opt/venv \
 && UV_NO_CACHE=1 uv pip install -q --python /opt/venv/bin/python -r /tmp/requirements.txt

RUN curl -fsSL https://omp.sh/install | PI_INSTALL_DIR=/usr/local/bin sh -s -- --binary --ref v18.16.0

# The host user's uid, so files written to the mounted engine directory belong to them.
ARG UID=1000 GID=1000
RUN (userdel -r ubuntu || true) \
 && groupadd -o -g $GID agent && useradd -o -m -u $UID -g $GID -s /bin/bash agent

COPY --chown=agent:agent <<EOF /home/agent/.omp/agent/models.yml
providers:
  sglang:
    baseUrl: http://sglang:30000/v1
    auth: none
    api: openai-completions
    models:
      - id: nvidia/Qwen3.8-27B-NVFP4
        name: Qwen3.8 27B NVFP4 (local SGLang)
        reasoning: true
        input: [text]
        contextWindow: 131072
        maxTokens: 32768
        cost: {input: 0, output: 0, cacheRead: 0, cacheWrite: 0}
        thinking:
          mode: effort
          efforts: [low, medium, xhigh]
          defaultLevel: low
          requiresEffort: false
        compat:
          thinkingFormat: qwen-chat-template
          reasoningContentField: reasoning_content
          qwenTemplateReasoningEffort: true
EOF

# Route every role to the local model so nothing falls back to a hosted provider.
COPY --chown=agent:agent <<EOF /home/agent/.omp/agent/config.yml
modelRoles:
  default: sglang/nvidia/Qwen3.8-27B-NVFP4
  smol: sglang/nvidia/Qwen3.8-27B-NVFP4:off
  slow: sglang/nvidia/Qwen3.8-27B-NVFP4
  plan: sglang/nvidia/Qwen3.8-27B-NVFP4
  tiny: sglang/nvidia/Qwen3.8-27B-NVFP4:off
  memory: sglang/nvidia/Qwen3.8-27B-NVFP4:off
EOF

USER agent
ENV PATH=/opt/venv/bin:$PATH PYTHONPATH=/workspace/python CUDA_HOME=/usr/local/cuda HF_HUB_OFFLINE=1
WORKDIR /workspace
