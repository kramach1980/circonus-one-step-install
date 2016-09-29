#!/usr/bin/env bash

# is this always true?
NAD_SCRIPTS_DIR=/opt/circonus/etc/node-agent.d
CASS_SCRIPTS_DIR=$NAD_SCRIPTS_DIR/cassandra

# determine if postgres is running
CASSREL=`nodetool version 2>/dev/null | grep ReleaseVersion`
if [ -z "$CASSREL" ]; then
    echo "Cassandra not detected, skipping setup"
    exit 1;
fi

CASSCLUSTER=`nodetool describecluster 2>/dev/null | grep Name | awk '{$1 = ""; print substr($0,2)}'`

# turn on all cassandra stuff
pushd $NAD_SCRIPTS_DIR >/dev/null
for i in $CASS_SCRIPTS_DIR/*; do
    ln -s $i .
done

# execute one of the scripts to ensure it's working
SECS=`./cassandra_info.sh | grep uptime_secs`
if [ -z "$SECS" ]; then
    echo "Could not execute a test script.  Is nodetool and gawk in your path"
    for i in $CASS_SCRIPTS_DIR/*; do
        rm `basename $i`
    done    
    echo "{\"enabled\": false}"    
    exit 1
fi

POPATH=`which protocol_observer`
PROTOCOL_OBSERVER="false"
if [ -n "$POPATH" ]; then
  PROTOCOL_OBSERVER="true"
fi

# ensure nad is exposing some of the new metrics
found=0
for i in {0..10}; do
    res=$(curl -sS localhost:2609/run/cassandra_info | grep -c '_value')
    if [[ $res -gt 0 ]]; then
        found=1
        break
    fi
    sleep 1
done

if [[ found -eq 0 ]]; then
    echo "{\"enabled\": false }"
    exit 1
fi


# find where the cassandra data is stored
DATA_DIR=""
DATA_DIR="$(echo -e "${DATA_DIR}" | tr -d '[[:space:]]')"
echo "{\"enabled\": true, \"data_dir\": \"${DATA_DIR}\", \"protocol_observer\": ${PROTOCOL_OBSERVER}, \"cluster_name\": \"${CASSCLUSTER}\" }"

popd >/dev/null

# if we have arrived here, the cassandra plugin in NAD is installed and operating 
exit 0