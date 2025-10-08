#!/bin/bash
#
# Basic Load Test for llama3-2-3b InferenceService
# Sends parallel requests to test the vLLM endpoint
#

API_BASE_URL="http://granite-8b-predictor.autoscaling-demo.svc.cluster.local:8080/v1"
MODEL_NAME="granite-8b"
NUM_REQUESTS=50

echo "Starting basic load test for $MODEL_NAME"
echo "Total requests: $NUM_REQUESTS"
echo "Endpoint: $API_BASE_URL/chat/completions"
echo "---"

for i in $(seq 1 $NUM_REQUESTS); do
    curl -X POST "$API_BASE_URL/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "'$MODEL_NAME'",
            "messages": [{"role": "user", "content": "Test request #'$i'"}],
            "max_tokens": 100
        }' \
        --silent \
        > /dev/null 2>&1 &
done

echo "Sent $NUM_REQUESTS requests in background"
wait
echo "All requests completed"
