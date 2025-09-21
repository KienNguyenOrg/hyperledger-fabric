#!/bin/bash


ORG=$1

export CHAINCODE_ID=chaincode-go-1-0_1.0:a9ba9e94c6c8924089648f83797f265d8bfc792d956b72b6251ac469a668ab39
export CHAINCODE_SERVER_ADDRESS=0.0.0.0:9999

export FABRIC_CFG_PATH=$PWD/config/org$ORG
export CA_FILE="$PWD/organizations/ordererOrganizations/atgdigitals.com/tlsca/tlsca.atgdigitals.com-cert.pem"
export CORE_TLS_CLIENT_CERT_FILE="$PWD/organizations/peerOrganizations/org$ORG.atgdigitals.com/peers/peer0.org$ORG.atgdigitals.com/tls/server.crt"
export CORE_TLS_CLIENT_KEY_PATH="$PWD/organizations/peerOrganizations/org$ORG.atgdigitals.com/peers/peer0.org$ORG.atgdigitals.com/tls/server.key"
export CORE_PEER_TLS_ROOTCERT_FILE="$PWD/organizations/peerOrganizations/org$ORG.atgdigitals.com/peers/peer0.org$ORG.atgdigitals.com/tls/ca.crt"
export CORE_PEER_MSPCONFIGPATH="$PWD/organizations/peerOrganizations/org$ORG.atgdigitals.com/users/Admin@org$ORG.atgdigitals.com/msp"
export CORE_PEER_TLS_ENABLED="true"
export CORE_PEER_LOCALMSPID="Org${ORG}MSP"
export CORE_PEER_ADDRESS="peer0.org$ORG.atgdigitals.com:7051"

echo $(ls $CORE_TLS_CLIENT_CERT_FILE)
echo $(ls $CORE_TLS_CLIENT_KEY_PATH)
echo $(ls $CORE_PEER_TLS_ROOTCERT_FILE)
echo $(ls $CORE_PEER_MSPCONFIGPATH)

./bin/fabric/peer lifecycle chaincode querycommitted --channelID default-channel

# ./bin/fabric/peer chaincode invoke   -C default-channel   -n chaincode-go-1-0   --peerAddresses $CORE_PEER_ADDRESS      --tlsRootCertFiles $CORE_PEER_TLS_ROOTCERT_FILE --tls --cafile $CA_FILE  -c '{"Args":["CreateAccount", "6"]}'