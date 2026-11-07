#!/bin/bash
# Open a shell in an engine's sandbox: its source at /workspace, the GPU, Qwen3-0.6B at /models/Qwen3-0.6B and the
# omp coding agent. No internet: the only server it can reach is SGLang, at http://sglang:30000.
# The sandbox keeps running after you exit the shell; run this again to get back in. usage: ./start.sh env1
set -euo pipefail
cd "$(dirname "$0")"
E=${1:?usage: ./start.sh env1}
E=${E%/}
[ -d "$E" ] || { echo "no $E directory; run ./setup.sh first" >&2; exit 1; }

if docker inspect sglang > /dev/null 2>&1; then
  docker inspect -f '{{json .NetworkSettings.Networks}}' sglang | grep -q '"workshop-net"' \
    || docker network connect workshop-net sglang
else
  echo "warning: the sglang container is not running (Step 2), so the agent has no model to talk to" >&2
fi

docker start workshop-$E > /dev/null 2>&1 \
  || docker run -d --init --name workshop-$E --network workshop-net --gpus all --shm-size 16g \
       -v "$PWD/$E":/workspace -v "$PWD/models/Qwen3-0.6B":/models/Qwen3-0.6B:ro \
       workshop-env sleep infinity > /dev/null
exec docker exec -it workshop-$E bash
