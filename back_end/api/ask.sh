#!/bin/bash
# 用法： ./ask.sh "QUESTION"

QUESTION="$1"

curl -s http://localhost:11434/api/generate \
  -d '{
    \"model\": \"deepseek-r1:7b\",
    \"prompt\": \"$QUESTION\",
    \"stream\": false
  }' \
| jq -r '.response' \
| sed 's/\\u003c/</g; s/\\u003e/>/g' \
| tr '\n' '\r' \
| sed 's/<think>.*<\/think>//g' \
| tr '\r' '\n'