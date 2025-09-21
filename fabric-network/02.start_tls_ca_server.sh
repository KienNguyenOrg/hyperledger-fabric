#!/bin/bash

. utils.sh

set -x

MODE=${1:-status}

export FABRIC_HOME=$PWD/fabric-ca/ordererOrg
systemctl $MODE fabric-ca-ordererOrg.service

export FABRIC_HOME=$PWD/fabric-ca/org1
systemctl $MODE fabric-ca-org1.service

export FABRIC_HOME=$PWD/fabric-ca/org2
systemctl $MODE fabric-ca-org2.service

export FABRIC_HOME=$PWD/fabric-ca/org3
systemctl $MODE fabric-ca-org3.service

sleep 3

{ set +x; } 2>/dev/null
