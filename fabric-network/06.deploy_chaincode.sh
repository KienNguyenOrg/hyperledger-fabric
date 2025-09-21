#!/bin/bash

. utils.sh

set -x

PEER1_HOST=$2
PEER2_HOST=$3
PEER3_HOST=$4
USERNAME=$5
WORKING_DIR=$6
CHANNEL_NAME=default-channel
CC_SRC_PATH=$1
CC_SRC_LANGUAGE=go
CC_RUNTIME_LANGUAGE=golang
CC_VERSION=1.0
CC_NAME="$(basename "$CC_SRC_PATH")-${CC_VERSION//./-}"
CC_SEQUENCE=auto
CC_INIT_FCN=NA
CC_END_POLICY="OutOf(2, 'Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')"
CC_COLL_CONFIG=NA
DELAY=3
MAX_RETRY=5
VERBOSE=false
CC_PACKAGE_ONLY=false

println "Executing with the following"
println "- CHANNEL_NAME: ${C_GREEN}${CHANNEL_NAME}${C_RESET}"
println "- CC_NAME: ${C_GREEN}${CC_NAME}${C_RESET}"
println "- CC_SRC_PATH: ${C_GREEN}${CC_SRC_PATH}${C_RESET}"
println "- CC_SRC_LANGUAGE: ${C_GREEN}${CC_SRC_LANGUAGE}${C_RESET}"
println "- CC_VERSION: ${C_GREEN}${CC_VERSION}${C_RESET}"
println "- CC_SEQUENCE: ${C_GREEN}${CC_SEQUENCE}${C_RESET}"
println "- CC_END_POLICY: ${C_GREEN}${CC_END_POLICY}${C_RESET}"
println "- CC_COLL_CONFIG: ${C_GREEN}${CC_COLL_CONFIG}${C_RESET}"
println "- CC_INIT_FCN: ${C_GREEN}${CC_INIT_FCN}${C_RESET}"
println "- DELAY: ${C_GREEN}${DELAY}${C_RESET}"
println "- MAX_RETRY: ${C_GREEN}${MAX_RETRY}${C_RESET}"
println "- VERBOSE: ${C_GREEN}${VERBOSE}${C_RESET}"

INIT_REQUIRED="--init-required"
# check if the init fcn should be called
if [ "$CC_INIT_FCN" = "NA" ]; then
  INIT_REQUIRED=""
fi

if [ "$CC_END_POLICY" = "NA" ]; then
  CC_END_POLICY=""
else
  CC_END_POLICY="--signature-policy $CC_END_POLICY"
fi

if [ "$CC_COLL_CONFIG" = "NA" ]; then
  CC_COLL_CONFIG=""
else
  CC_COLL_CONFIG="--collections-config $CC_COLL_CONFIG"
fi

function packageChaincode() {
  if [ -f "packagedChaincode/${CC_NAME}.tar.gz" ]; then
    infoln "Chaincode file exists at packagedChaincode/${CC_NAME}.tar.gz"
  else 
    export FABRIC_CFG_PATH=$PWD/config/org1
    set -x
    mkdir -p packagedChaincode
    $PWD/bin/fabric/peer lifecycle chaincode package packagedChaincode/${CC_NAME}.tar.gz --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} --label ${CC_NAME}_${CC_VERSION} >> log.txt 2>&1
    res=$?
    { set +x; } 2>/dev/null
    cat log.txt
    PACKAGE_ID=$($PWD/bin/fabric/peer lifecycle chaincode calculatepackageid packagedChaincode/${CC_NAME}.tar.gz)
    verifyResult $res "Chaincode packaging has failed"
    successln "Chaincode is packaged"
  fi
}

packageChaincodeAAS() {
  mkdir -p packagedChaincode
  
  address="peer0.org{{.org}}.atgdigitals.com:9999"
  prefix=$(basename "$0")
  tempdir=$(mktemp -d -t "$prefix.XXXXXXXX") || error_exit "Error creating temporary directory"
  label=${CC_NAME}_${CC_VERSION}
  mkdir -p "$tempdir/src"

cat > "$tempdir/src/connection.json" <<CONN_EOF
{
  "address": "${address}",
  "dial_timeout": "10s",
  "tls_required": false
}
CONN_EOF

   mkdir -p "$tempdir/pkg"

cat << METADATA-EOF > "$tempdir/pkg/metadata.json"
{
    "type": "external",
    "label": "$label"
}
METADATA-EOF

    tar -C "$tempdir/src" -czf "$tempdir/pkg/code.tar.gz" .
    tar -C "$tempdir/pkg" -czf "packagedChaincode/$CC_NAME.tar.gz" metadata.json code.tar.gz
    rm -Rf "$tempdir"

    PACKAGE_ID=$($PWD/bin/fabric/peer lifecycle chaincode calculatepackageid packagedChaincode/${CC_NAME}.tar.gz)
  
    successln "Chaincode is packaged ${address}"
}

function installChaincode() {
  ORG=$1
  local HOST=PEER${ORG}_HOST
  export FABRIC_CFG_PATH=$PWD/config/org$ORG
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/tlsca/tlsca.org${ORG}.atgdigitals.com-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/users/Admin@org${ORG}.atgdigitals.com/msp
  export CORE_PEER_ADDRESS=${!HOST}:7051
  export CORE_PEER_LOCALMSPID=Org${ORG}MSP

  set -x
  $PWD/bin/fabric/peer lifecycle chaincode queryinstalled --output json | jq -r 'try (.installed_chaincodes[].package_id)' | grep ^${PACKAGE_ID}$ >> log.txt 2>&1
  if test $? -ne 0; then
    $PWD/bin/fabric/peer lifecycle chaincode install packagedChaincode/${CC_NAME}.tar.gz >> log.txt 2>&1
    res=$?
  fi
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode installation on peer0.org${ORG} has failed"
  successln "Chaincode is installed on peer0.org${ORG}"
}

function resolveSequence() {
  export FABRIC_CFG_PATH=$PWD/config/org1
  #if the sequence is not "auto", then use the provided sequence
  if [[ "${CC_SEQUENCE}" != "auto" ]]; then
    return 0
  fi

  local rc=1
  local COUNTER=1
  # first, find the sequence number of the committed chaincode
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    set -x
    COMMITTED_CC_SEQUENCE=$($PWD/bin/fabric/peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME} | sed -n "/Version:/{s/.*Sequence: //; s/, Endorsement Plugin:.*$//; p;}")
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res    
    COUNTER=$(expr $COUNTER + 1)
  done

  # if there are no committed versions, then set the sequence to 1
  if [ -z $COMMITTED_CC_SEQUENCE ]; then
    CC_SEQUENCE=1
    return 0
  fi

  rc=1
  COUNTER=1
  # next, find the sequence number of the approved chaincode
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    set -x
    APPROVED_CC_SEQUENCE=$($PWD/bin/fabric/peer lifecycle chaincode queryapproved --channelID $CHANNEL_NAME --name ${CC_NAME} | sed -n "/sequence:/{s/^sequence: //; s/, version:.*$//; p;}")
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done

  # if the committed sequence and the approved sequence match, then increment the sequence
  # otherwise, use the approved sequence
  if [ $COMMITTED_CC_SEQUENCE == $APPROVED_CC_SEQUENCE ]; then
    CC_SEQUENCE=$((COMMITTED_CC_SEQUENCE+1))
  else
    CC_SEQUENCE=$APPROVED_CC_SEQUENCE
  fi
}

function queryInstalled() {
  ORG=$1
  local HOST=PEER${ORG}_HOST
  export FABRIC_CFG_PATH=$PWD/config/org$ORG
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/tlsca/tlsca.org${ORG}.atgdigitals.com-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/users/Admin@org${ORG}.atgdigitals.com/msp
  export CORE_PEER_ADDRESS=${!HOST}:7051
  export CORE_PEER_LOCALMSPID=Org${ORG}MSP

  set -x
  $PWD/bin/fabric/peer lifecycle chaincode queryinstalled --output json | jq -r 'try (.installed_chaincodes[].package_id)' | grep ^${PACKAGE_ID}$ >> log.txt 2>&1
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Query installed on peer0.org${ORG} has failed"
  successln "Query installed successful on peer0.org${ORG} on channel"
}

function approveForMyOrg() {
  ORG=$1
  local HOST=PEER${ORG}_HOST
  export FABRIC_CFG_PATH=$PWD/config/org$ORG
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/tlsca/tlsca.org${ORG}.atgdigitals.com-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/users/Admin@org${ORG}.atgdigitals.com/msp
  export CORE_PEER_ADDRESS=${!HOST}:7051
  export CORE_PEER_LOCALMSPID=Org${ORG}MSP
  ORDERER_CA=${PWD}/organizations/ordererOrganizations/org${ORG}.atgdigitals.com/tlsca/tlsca.org${ORG}.atgdigitals.com-cert.pem

  set -x
  $PWD/bin/fabric/peer lifecycle chaincode approveformyorg -o orderer$ORG.atgdigitals.com:7050 --ordererTLSHostnameOverride orderer$ORG.atgdigitals.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --package-id ${PACKAGE_ID} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} --signature-policy "OutOf(2, 'Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" ${CC_COLL_CONFIG} >> log.txt 2>&1
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME' failed"
  successln "Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME'"
}

function checkCommitReadiness() {
  ORG=$1
  shift 1
  local HOST=PEER${ORG}_HOST
  export FABRIC_CFG_PATH=$PWD/config/org$ORG
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/tlsca/tlsca.org${ORG}.atgdigitals.com-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/users/Admin@org${ORG}.atgdigitals.com/msp
  export CORE_PEER_ADDRESS=${!HOST}:7051
  export CORE_PEER_LOCALMSPID=Org${ORG}MSP

  infoln "Checking the commit readiness of the chaincode definition on peer0.org${ORG} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to check the commit readiness of the chaincode definition on peer0.org${ORG}, Retry after $DELAY seconds."
    set -x
    output=$($PWD/bin/fabric/peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} --signature-policy "OutOf(2, 'Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" ${CC_COLL_CONFIG} --output json 2>&1)
    res=$?
    { set +x; } 2>/dev/null
    let rc=0
    for var in "$@"; do
      grep -q "$var" <<<"$output" || rc=1
    done
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  if test $rc -eq 0; then
    infoln "Checking the commit readiness of the chaincode definition successful on peer0.org${ORG} on channel '$CHANNEL_NAME'"
  else
    fatalln "After $MAX_RETRY attempts, Check commit readiness result on peer0.org${ORG} is INVALID!"
  fi
}

function commitChaincodeDefinition() {
  parsePeerConnectionParameters $@

  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME' due to uneven number of peer and org parameters "

  # while 'peer chaincode' command can get the orderer endpoint from the
  # peer (if join was successful), let's supply it directly as we know
  # it using the "-o" option
  ORDERER_CA=${PWD}/organizations/ordererOrganizations/org1.atgdigitals.com/tlsca/tlsca.org1.atgdigitals.com-cert.pem
  set -x
  $PWD/bin/fabric/peer lifecycle chaincode commit -o orderer1.atgdigitals.com:7050 --ordererTLSHostnameOverride orderer1.atgdigitals.com --tls --cafile "$ORDERER_CA" --channelID $CHANNEL_NAME --name ${CC_NAME} "${PEER_CONN_PARMS[@]}" --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} --signature-policy "OutOf(2, 'Org1MSP.member', 'Org2MSP.member', 'Org3MSP.member')" ${CC_COLL_CONFIG} >> log.txt 2>&1
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode definition commit failed on peer0.org${ORG} on channel '$CHANNEL_NAME' failed"
  successln "Chaincode definition committed on channel '$CHANNEL_NAME'"
}

function queryCommitted() {
  ORG=$1
  local HOST=PEER${ORG}_HOST
  export FABRIC_CFG_PATH=$PWD/config/org$ORG
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/tlsca/tlsca.org${ORG}.atgdigitals.com-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/users/Admin@org${ORG}.atgdigitals.com/msp
  export CORE_PEER_ADDRESS=${!HOST}:7051
  export CORE_PEER_LOCALMSPID=Org${ORG}MSP

  EXPECTED_RESULT="Version: ${CC_VERSION}, Sequence: ${CC_SEQUENCE}, Endorsement Plugin: escc, Validation Plugin: vscc"
  infoln "Querying chaincode definition on peer0.org${ORG} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  # continue to poll
  # we either get a successful response, or reach MAX RETRY
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    infoln "Attempting to Query committed status on peer0.org${ORG}, Retry after $DELAY seconds."
    set -x
    $PWD/bin/fabric/peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME} > log.txt 2>&1
    res=$?
    { set +x; } 2>/dev/null
    test $res -eq 0 && VALUE=$(cat log.txt | grep -o '^Version: '$CC_VERSION', Sequence: [0-9]*, Endorsement Plugin: escc, Validation Plugin: vscc')
    test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  if test $rc -eq 0; then
    successln "Query chaincode definition successful on peer0.org${ORG} on channel '$CHANNEL_NAME'"
  else
    fatalln "After $MAX_RETRY attempts, Query chaincode definition result on peer0.org${ORG} is INVALID!"
  fi
}

## package the chaincode
packageChaincodeAAS 
export FABRIC_CFG_PATH=$PWD/config/org1
PACKAGE_ID=$($PWD/bin/fabric/peer lifecycle chaincode calculatepackageid packagedChaincode/${CC_NAME}.tar.gz)

## Install chaincode on peer0.org1 and peer0.org2
# infoln "Installing chaincode on peer0.org1..."
installChaincode 1
# infoln "Install chaincode on peer0.org2..."
installChaincode 2
# infoln "Install chaincode on peer0.org3..."
installChaincode 3

resolveSequence

## query whether the chaincode is installed
queryInstalled 1

## Start external chaincode server
./05.start_chaincode_server.sh $PACKAGE_ID 1
ssh $USERNAME@peer0.org2.atgdigitals.com "cd $WORKING_DIR/hyperledger/fabric-network && sudo bash ./05.start_chaincode_server.sh $PACKAGE_ID 2"
ssh $USERNAME@peer0.org3.atgdigitals.com "cd $WORKING_DIR/hyperledger/fabric-network && sudo bash ./05.start_chaincode_server.sh $PACKAGE_ID 3"

## approve the definition for org1
approveForMyOrg 1

## check whether the chaincode definition is ready to be committed
## expect org1 to have approved and org2 not to
checkCommitReadiness 1 "\"Org1MSP\": true"

## now approve also for org2
approveForMyOrg 2

## check whether the chaincode definition is ready to be committed
## expect them both to have approved
# checkCommitReadiness 2 "\"Org2MSP\": true"

## now approve also for org3
approveForMyOrg 3

## now that we know for sure both orgs have approved, commit the definition
# commitChaincodeDefinition 1 $PEER1_HOST
commitChaincodeDefinition 1 $PEER1_HOST 2 $PEER2_HOST 3 $PEER3_HOST

## query on both orgs to see that the definition committed successfully
queryCommitted 1
queryCommitted 2
queryCommitted 3

## Invoke the chaincode - this does require that the chaincode have the 'initLedger'
## method defined
if [ "$CC_INIT_FCN" = "NA" ]; then
  infoln "Chaincode initialization is not required"
else
  chaincodeInvokeInit 1 2
fi

{ set +x; } 2>/dev/null
