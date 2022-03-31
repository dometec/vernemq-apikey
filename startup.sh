#!/bin/bash

echo "Checking VerneMQ configuration..."

sed -i.bak -r "s/-setcookie.+/-setcookie ${DOCKER_VERNEMQ_DISTRIBUTED_COOKIE}/" /vernemq/etc/vm.args
sed -i.bak -r "s/-name.+/-name ${DOCKER_VERNEMQ_NODENAME}/" /vernemq/etc/vm.args

env | grep DOCKER_VERNEMQ | grep -v 'DISCOVERY_NODE\|KUBERNETES\|SWARM\|COMPOSE\|DOCKER_VERNEMQ_USER' | cut -c 16- | awk '{match($0,/^[A-Z0-9_]*/)}{print tolower(substr($0,RSTART,RLENGTH)) substr($0,RLENGTH+1)}' | sed 's/__/./g' >> /vernemq/etc/vernemq.conf

# Check configuration file
/vernemq/bin/vernemq config generate 2>&1 > /dev/null | tee /tmp/config.out | grep error

if [ $? -ne 1 ]; then
    echo "configuration error, exit"
    echo "$(cat /tmp/config.out)"
    exit $?
fi

# SIGUSR1-handler
siguser1_handler() {
    echo "stopped"
}

# SIGTERM-handler
sigterm_handler() {
    /vernemq/bin/vmq-admin cluster leave node=${DOCKER_VERNEMQ_NODENAME} -k
    /vernemq/bin/vmq-admin node stop
}

# Setup OS signal handlers
trap 'siguser1_handler' SIGUSR1
trap 'sigterm_handler' SIGTERM

# Start VerneMQ
/vernemq/bin/vernemq console -noshell -noinput $@ &
sleep 30 && echo "Adding API_KEY..." && /vernemq/bin/vmq-admin api-key add key=${APIKEY:-DEFAULT}
vmq-admin api-key show
wait $pid

