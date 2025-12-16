#!/bin/bash

# Check for correct number of arguments
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <Bytes> <NumNPUs> <Operation>"
  echo "Example: $0 32000 16 ALLGATHER"
  exit 1
fi

BYTES=$1
NPUS=$2
OP=$3

# File and directory names (based on operation)
INPUT_FILE="micro${OP}${BYTES}B.txt"
OUTPUT_DIR="${OP}${BYTES}B_${NPUS}"
OUTPUT_PATH="${OUTPUT_DIR}/${OP}${BYTES}B_${NPUS}"

# Remove previous input file and output directory if they exist
[ -f "$INPUT_FILE" ] && rm "$INPUT_FILE"
[ -d "$OUTPUT_DIR" ] && rm -rf "$OUTPUT_DIR"

# Create input text file
cat <<EOF > "$INPUT_FILE"
MICRO
1
conv1 -1 5 NONE 0 5 NONE 0 5  ${OP} ${BYTES} 5
EOF

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Run the chakra_converter command
chakra_converter Text \
  --input="./$INPUT_FILE" \
  --output="./$OUTPUT_PATH" \
  --num-npus="$NPUS" \
  --num-passes=1

