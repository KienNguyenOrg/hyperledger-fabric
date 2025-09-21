#!/bin/bash

. utils.sh

set -x

ADMIN_USER=tlsadmin01
ADMIN_PWD=tlsadminpw

mkdir -p organizations/fabric-ca/{ordererOrg1,ordererOrg2,ordererOrg3,org1,org2,org3}
FABRIC_HOME=$PWD

function init() {
    local NAME=$1
    local IDX=$(echo "$NAME" | sed 's/[^0-9]//g')
    local PUBLIC_PORT=$2
    local OPS_PORT=$3

    cd $FABRIC_HOME/organizations/fabric-ca/$NAME
    if [ -d "$PWD" ] && [ "$(ls -A "$PWD")" ]; then
        echo "$PWD already exists"
        return 1
    fi 

    CSR_HOST=orderer.atgdigitals.com
    if [[ $NAME == *"orderer"* ]]; then 
        CSR_HOST=orderer$IDX.atgdigitals.com
    elif [[ $NAME == *"org"* ]]; then 
        CSR_HOST=peer0.$NAME.atgdigitals.com
    fi
    # Initialize the TLS CA server
    $FABRIC_HOME/bin/fabric-ca-server init -b "$ADMIN_USER":"$ADMIN_PWD" -n $CSR_HOST
    sed -i "s/port: 7054/port: $PUBLIC_PORT/g" fabric-ca-server-config.yaml
    sed -i "s/listenAddress: 127.0.0.1:9443/listenAddress: 0.0.0.0:$OPS_PORT/g" fabric-ca-server-config.yaml
}


DELPOY=$1

if [ "${DELPOY,,}" = "orderer1" ]; then
    init orderer1 5054 7443
elif [ "${DELPOY,,}" = "orderer2" ]; then
    init orderer2 6054 8443
elif [ "${DELPOY,,}" = "orderer3" ]; then
    init orderer3 7054 9443
elif [ "${DELPOY,,}" = "org1" ]; then
    init org1 8054 10443
elif [ "${DELPOY,,}" = "org2" ]; then
    init org2 9054 11443
elif [ "${DELPOY,,}" = "org3" ]; then
    init org3 10054 12443
elif [ "${DELPOY,,}" = "all" ]; then
    init ordererOrg1 5054 7443
    init ordererOrg2 6054 8443
    init ordererOrg3 7054 9443
    init org1 8054 10443
    init org2 9054 11443
    init org3 10054 12443
fi

{ set +x; } 2>/dev/null
