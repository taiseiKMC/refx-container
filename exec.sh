#!/bin/bash -e 
MAX_RETRY=50
INTERVAL=5
shopt -s expand_aliases

./src/bin_node/tezos-sandboxed-node.sh 1 --connections 1 > /dev/null &

for i in $(seq 1 $MAX_RETRY); do
    ./tezos-client -P 18731 rpc get /protocols >& /dev/null && break
    sleep $INTERVAL
done

eval `./src/bin_client/tezos-init-sandboxed-client.sh 1`
tezos-activate-alpha

exec "$@"
