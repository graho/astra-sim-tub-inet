#!/bin/bash

# Check arguments
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <endpoint_delay_ns> <algorithm>"
  echo "Example: $0 150 halvingDoubling"
  exit 1
fi

ENDPOINT_DELAY=$1
ALGO=$2

# Output file name
OUTPUT_FILE="system_${ALGO}_${ENDPOINT_DELAY}ns.json"

# Generate JSON content
cat <<EOF > "$OUTPUT_FILE"
{
    "scheduling-policy": "LIFO",
    "endpoint-delay": $ENDPOINT_DELAY,
    "active-chunks-per-dimension": 1,
    "preferred-dataset-splits": 1,
    "all-reduce-implementation": [
        "$ALGO"
    ],
    "all-gather-implementation": [
        "$ALGO"
    ],
    "reduce-scatter-implementation": [
        "$ALGO"
    ],
    "all-to-all-implementation": [
        "$ALGO"
    ],
    "collective-optimization": "baseline",
    "local-mem-bw": 1600,
    "boost-mode": 0
}
EOF

echo "Configuration written to $OUTPUT_FILE"

