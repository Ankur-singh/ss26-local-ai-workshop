#!/bin/bash
# Compare an engine with the original mini-sglang on Qwen3-0.6B: greedy outputs must match token for token, and the
# benchmark for the engine's broken optimization should be within 5% of the original. The original's numbers are
# measured the first time they are needed and reused (delete results/original to measure them again).
# usage: ./verify.sh env1
set -euo pipefail
cd "$(dirname "$0")"
E=${1:?usage: ./verify.sh env1}
E=${E%/}
[ -d "$E" ] || { echo "no $E directory; run ./setup.sh first" >&2; exit 1; }
case $E in  # must follow the env-to-patch mapping in setup.sh
  env1) TESTS="check long_prompt" ;;
  env2) TESTS="check latency" ;;
  env3) TESTS="check prefix" ;;
  env4) TESTS="check offline" ;;
  *) echo "no benchmark for $E; choose env1, env2, env3 or env4" >&2; exit 1 ;;
esac

bench() {  # <source dir> <results dir> <test...>
  local src=$1 out=$2
  shift 2
  mkdir -p $out .cache
  docker run --rm --network none --gpus all --shm-size 16g \
    -v "$PWD/$src":/src:ro -v "$PWD/$out":/out -v "$PWD/bench.py":/bench.py:ro \
    -v "$PWD/models/Qwen3-0.6B":/models/Qwen3-0.6B:ro -v "$PWD/.cache":/home/agent/.cache \
    -e PYTHONPATH=/src/python workshop-env python /bench.py run /out "$@"
}

MISSING=$(for t in $TESTS; do [ -f results/original/$t.json ] || echo $t; done)
if [ -n "$MISSING" ]; then
  echo "measuring the original (first time only)"
  bench .original results/original $MISSING || true
fi
echo "measuring $E"
rm -rf results/$E
bench $E results/$E $TESTS || true
echo
python3 bench.py compare results/original results/$E $TESTS
