#!/bin/bash

# Check if a number of nodes is given
echo "Running generate_logical_topo.sh"

if [ -z "$1" ]; then
  echo "Usage: $0 <numNodes>"
  exit 1
fi

numNodes=$1
filename="sample_${numNodes}nodes_1D.json"

cat > "$filename" <<EOF
{
    "logical-dims": ["${numNodes}"]
}
EOF


