#!/bin/bash
# 用法： ./ask.sh "QUESTION"


set -euo pipefail

QUESTION="${1:-}"

# 用 jq 安全組 JSON payload
payload=$(jq -n \
  --arg model   "deepseek-coder:1.3b" \
  --arg prompt  "$QUESTION" \
  --argjson stream false \
  '{model:$model, prompt:$prompt, stream:$stream}')

curl -s -H 'Content-Type: application/json' \
  http://localhost:11434/api/generate \
  -d "$payload" \
| jq -r '.response // ""' \
| perl -0777 -pe 's{<think>.*?</think>}{}gs'