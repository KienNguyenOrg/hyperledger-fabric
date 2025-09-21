#!/bin/bash

. utils.sh

set -x

MODE=${1:-status}

systemctl $MODE fabric-ca-ordererOrg1.service

systemctl $MODE fabric-ca-ordererOrg2.service

systemctl $MODE fabric-ca-ordererOrg3.service

systemctl $MODE fabric-ca-org1.service

systemctl $MODE fabric-ca-org2.service

systemctl $MODE fabric-ca-org3.service

sleep 3

{ set +x; } 2>/dev/null
