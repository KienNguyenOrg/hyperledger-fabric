#!/bin/bash

. utils.sh

set -x

ADMIN_USER=tlsadmin01
ADMIN_PWD=tlsadminpw


# Enroll bootstrap admin identity with TLS CA
FABRIC_HOME=$PWD
set -e

##################################################################
enrollOrder() {
    local NAME=$1
    local IDX=$(echo "$NAME" | sed 's/[^0-9]//g')
    local CA_HOST=$2
    local CA_PORT=$3
    local ORDERER=orderer
    
    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com
    mkdir -p $FABRIC_CA_CLIENT_HOME
    $FABRIC_HOME/bin/fabric-ca-client enroll -u "https://$ADMIN_USER:$ADMIN_PWD@orderer1.atgdigitals.com:$CA_PORT" --tls.certfiles $PWD/organizations/fabric-ca/$NAME/ca-cert.pem --csr.hosts $CA_HOST

    echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
        Certificate: cacerts/$CA_HOST-$CA_PORT.pem
        OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
        Certificate: cacerts/$CA_HOST-$CA_PORT.pem
        OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
        Certificate: cacerts/$CA_HOST-$CA_PORT.pem
        OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
        Certificate: cacerts/$CA_HOST-$CA_PORT.pem
        OrganizationalUnitIdentifier: orderer" > "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/msp/config.yaml"

    CA_HOST=orderer1.atgdigitals.com
    mkdir -p "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/msp/tlscacerts"
    cp "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem" "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/msp/tlscacerts/tlsca.org$IDX.atgdigitals.com-cert.pem"

    # Copy orderer org's CA cert to orderer org's /tlsca directory (for use by clients)
    mkdir -p "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/tlsca"
    cp "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem" "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/tlsca/tlsca.org$IDX.atgdigitals.com-cert.pem"

    $FABRIC_HOME/bin/fabric-ca-client register --id.name ${ORDERER} --id.secret ${ORDERER}pw --id.type orderer --tls.certfiles "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem"
    $FABRIC_HOME/bin/fabric-ca-client enroll -u https://${ORDERER}:${ORDERER}pw@$CA_HOST:$CA_PORT -M "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem"
    cp "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/msp/config.yaml" "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/msp/config.yaml"
    mv "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/msp/signcerts/cert.pem" "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/msp/signcerts/orderer${IDX}.atgdigitals.com-cert.pem"
    $FABRIC_HOME/bin/fabric-ca-client enroll -u https://${ORDERER}:${ORDERER}pw@$CA_HOST:$CA_PORT -M "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/tls" --enrollment.profile tls --csr.hosts orderer${IDX}.atgdigitals.com --tls.certfiles "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem"

    # Copy the tls CA cert, server cert, server keystore to well known file names in the orderer's tls directory that are referenced by orderer startup config
    cp "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/tls/tlscacerts/"* "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/tls/ca.crt"
    cp "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/tls/signcerts/"* "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/tls/server.crt"
    cp "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/tls/keystore/"* "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/tls/server.key"

    # Copy orderer org's CA cert to orderer's /msp/tlscacerts directory (for use in the orderer MSP definition)
    mkdir -p "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/msp/tlscacerts"
    cp "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/tls/tlscacerts/"* "${PWD}/organizations/ordererOrganizations/org${IDX}.atgdigitals.com/orderers/orderer${IDX}.atgdigitals.com/msp/tlscacerts/tlsca.org$IDX.atgdigitals.com-cert.pem"
}
##################################################################
enrollOrg() {
    local NAME=$1
    local CA_HOST=$2
    local CA_PORT=$3

    export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com
    mkdir -p $FABRIC_CA_CLIENT_HOME
    $FABRIC_HOME/bin/fabric-ca-client enroll -u "https://$ADMIN_USER:$ADMIN_PWD@peer0.org1.atgdigitals.com:$CA_PORT" --tls.certfiles $PWD/organizations/fabric-ca/$NAME/ca-cert.pem --csr.hosts $CA_HOST

    echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
        Certificate: cacerts/$CA_HOST-$CA_PORT.pem
        OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
        Certificate: cacerts/$CA_HOST-$CA_PORT.pem
        OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
        Certificate: cacerts/$CA_HOST-$CA_PORT.pem
        OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
        Certificate: cacerts/$CA_HOST-$CA_PORT.pem
        OrganizationalUnitIdentifier: orderer" > "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/msp/config.yaml"

    CA_HOST=peer0.org1.atgdigitals.com
    mkdir -p "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/msp/tlscacerts"
    cp "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem" "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/msp/tlscacerts/ca.crt"

    mkdir -p "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/tlsca"
    cp "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem" "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/tlsca/tlsca.$NAME.atgdigitals.com-cert.pem"

    mkdir -p "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/ca"
    cp "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem" "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/ca/ca.$NAME.atgdigitals.com-cert.pem"

    $FABRIC_HOME/bin/fabric-ca-client register --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem"

    $FABRIC_HOME/bin/fabric-ca-client register --id.name user1 --id.secret user1pw --id.type client --tls.certfiles "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem"

    $FABRIC_HOME/bin/fabric-ca-client register --id.name ${NAME}admin --id.secret ${NAME}adminpw --id.type admin --tls.certfiles "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem"

    $FABRIC_HOME/bin/fabric-ca-client enroll -u https://peer0:peer0pw@$CA_HOST:$CA_PORT -M "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/peers/peer0.$NAME.atgdigitals.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem"

    cp "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/peers/peer0.$NAME.atgdigitals.com/msp/config.yaml"

    $FABRIC_HOME/bin/fabric-ca-client enroll -u https://peer0:peer0pw@$CA_HOST:$CA_PORT -M "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/peers/peer0.$NAME.atgdigitals.com/tls" --enrollment.profile tls --csr.hosts peer0.$NAME.atgdigitals.com --csr.hosts peer0.$NAME.atgdigitals.com --tls.certfiles "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem"

    cp "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/peers/peer0.$NAME.atgdigitals.com/tls/tlscacerts/"* "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/peers/peer0.$NAME.atgdigitals.com/tls/ca.crt"
    cp "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/peers/peer0.$NAME.atgdigitals.com/tls/signcerts/"* "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/peers/peer0.$NAME.atgdigitals.com/tls/server.crt"
    cp "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/peers/peer0.$NAME.atgdigitals.com/tls/keystore/"* "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/peers/peer0.$NAME.atgdigitals.com/tls/server.key"

    $FABRIC_HOME/bin/fabric-ca-client enroll -u https://user1:user1pw@$CA_HOST:$CA_PORT -M "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/users/User1@$NAME.atgdigitals.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem"

    cp "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/users/User1@$NAME.atgdigitals.com/msp/config.yaml"

    $FABRIC_HOME/bin/fabric-ca-client enroll -u https://${NAME}admin:${NAME}adminpw@$CA_HOST:$CA_PORT -M "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/users/Admin@$NAME.atgdigitals.com/msp" --tls.certfiles "${PWD}/organizations/fabric-ca/$NAME/ca-cert.pem"

    cp "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/msp/config.yaml" "${PWD}/organizations/peerOrganizations/$NAME.atgdigitals.com/users/Admin@$NAME.atgdigitals.com/msp/config.yaml"
}


enrollOrder ordererOrg1  orderer1.atgdigitals.com 5054
enrollOrder ordererOrg2  orderer2.atgdigitals.com 6054
enrollOrder ordererOrg3  orderer3.atgdigitals.com 7054
enrollOrg   org1        peer0.org1.atgdigitals.com 8054
enrollOrg   org2        peer0.org2.atgdigitals.com 9054
enrollOrg   org3        peer0.org3.atgdigitals.com 10054

sleep 3

{ set +x; } 2>/dev/null
