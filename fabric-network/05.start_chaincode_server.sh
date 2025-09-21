#!/bin/bash

CHAINCODE_ID=$1
ORG=$2

# Edit env file 
sed "s|{{CHAINCODE_ID}}|$CHAINCODE_ID|" $PWD/env/fabric-chaincode.conf.template > $PWD/env/fabric-chaincode.conf
sed -i "s|{{PWD}}|$PWD|" $PWD/env/fabric-chaincode.conf
sed -i "s|{{ORG}}|$ORG|" $PWD/env/fabric-chaincode.conf

chmod +x $PWD/bin/chaincode/chaincode

sudo bash -c "systemctl restart fabric-chaincode.service"
