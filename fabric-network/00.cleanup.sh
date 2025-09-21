#!/bin/bash

. ./utils.sh

set -x

rm -rf organizations
rm -rf channel-artifacts
rm -rf chain-data
rm -rf packagedChaincode
rm -rf config/ordererOrg/orderer.yaml
rm -rf config/org1/core.yaml
rm -rf config/org2/core.yaml
rm -rf config/org3/core.yaml

{ set +x; } 2>/dev/null
