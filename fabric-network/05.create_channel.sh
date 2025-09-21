#!/bin/bash

. utils.sh

set -x

CHANNEL_NAME=default-channel
DELAY="3"
MAX_RETRY="5"

ORDERER1_HOST=orderer1.atgdigitals.com
ORDERER2_HOST=orderer2.atgdigitals.com
ORDERER3_HOST=orderer3.atgdigitals.com
PEER1_HOST=peer0.org1.atgdigitals.com
PEER2_HOST=peer0.org2.atgdigitals.com
PEER3_HOST=peer0.org3.atgdigitals.com

mkdir -p channel-artifacts

createChannelGenesisBlock() {
    $PWD/bin/fabric/configtxgen -profile ChannelUsingRaft -outputBlock $PWD/channel-artifacts/${CHANNEL_NAME}.block -channelID $CHANNEL_NAME
    res=$?
    verifyResult $res "Failed to generate channel configuration transaction..."
}

createChannel() {
	# Poll in case the raft leader is not set yet
	local ORG=$1
  local rc=1
	local COUNTER=1
	echo "Adding orderers"
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		set -x
        ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/org$ORG.atgdigitals.com/orderers/orderer$ORG.atgdigitals.com/tls/server.crt 
        ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/org$ORG.atgdigitals.com/orderers/orderer$ORG.atgdigitals.com/tls/server.key
        ORDERER_CA=${PWD}/organizations/ordererOrganizations/org$ORG.atgdigitals.com/orderers/orderer$ORG.atgdigitals.com/tls/ca.crt
        $PWD/bin/fabric/osnadmin channel join --channelID ${CHANNEL_NAME} --config-block $PWD/channel-artifacts/${CHANNEL_NAME}.block -o orderer$ORG.atgdigitals.com:9443 --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY" >> log.txt 2>&1
		res=$?
		{ set +x; } 2>/dev/null
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	verifyResult $res "Channel creation failed"
}

# joinChannel ORG
joinChannel() {
  ORG=$1
	local rc=1
	local COUNTER=1
	local HOST=PEER${ORG}_HOST
  export CORE_PEER_LOCALMSPID=Org${ORG}MSP
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/tlsca/tlsca.org${ORG}.atgdigitals.com-cert.pem
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/users/Admin@org${ORG}.atgdigitals.com/msp
  export CORE_PEER_ADDRESS=${!HOST}:7051

  ## Sometimes Join takes time, hence retry
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    set -x
    $PWD/bin/fabric/peer channel join -b $BLOCKFILE >> log.txt 2>&1
    res=$?
    { set +x; } 2>/dev/null
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	verifyResult $res "After $MAX_RETRY attempts, peer0.org${ORG} has failed to join channel '$CHANNEL_NAME' "
}

fetchChannelConfig() {
  ORG=$1
  CHANNEL=$2
  OUTPUT=$3

  echo "Fetching the most recent configuration block for the channel"
  set -x
  ORDERER_CA=${PWD}/organizations/ordererOrganizations/org$ORG.atgdigitals.com/orderers/orderer$ORG.atgdigitals.com/tls/ca.crt
  $PWD/bin/fabric/peer channel fetch config ${PWD}/channel-artifacts/config_block.pb -o orderer$ORG.atgdigitals.com:7050 --ordererTLSHostnameOverride orderer$ORG.atgdigitals.com -c $CHANNEL --tls --cafile "$ORDERER_CA"
  { set +x; } 2>/dev/null

  echo "Decoding config block to JSON and isolating config to ${OUTPUT}"
  set -x
  $PWD/bin/fabric/configtxlator proto_decode --input ${PWD}/channel-artifacts/config_block.pb --type common.Block --output ${PWD}/channel-artifacts/config_block.json
  jq .data.data[0].payload.data.config ${PWD}/channel-artifacts/config_block.json >"${OUTPUT}"
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Failed to parse channel configuration, make sure you have jq installed"
}

createConfigUpdate() {
  CHANNEL=$1
  ORIGINAL=$2
  MODIFIED=$3
  OUTPUT=$4

  set -x
  $PWD/bin/fabric/configtxlator proto_encode --input "${ORIGINAL}" --type common.Config --output ${PWD}/channel-artifacts/original_config.pb
  $PWD/bin/fabric/configtxlator proto_encode --input "${MODIFIED}" --type common.Config --output ${PWD}/channel-artifacts/modified_config.pb
  $PWD/bin/fabric/configtxlator compute_update --channel_id "${CHANNEL}" --original ${PWD}/channel-artifacts/original_config.pb --updated ${PWD}/channel-artifacts/modified_config.pb --output ${PWD}/channel-artifacts/config_update.pb
  $PWD/bin/fabric/configtxlator proto_decode --input ${PWD}/channel-artifacts/config_update.pb --type common.ConfigUpdate --output ${PWD}/channel-artifacts/config_update.json
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":'$(cat ${PWD}/channel-artifacts/config_update.json)'}}}' | jq . > ${PWD}/channel-artifacts/config_update_in_envelope.json
  $PWD/bin/fabric/configtxlator proto_encode --input ${PWD}/channel-artifacts/config_update_in_envelope.json --type common.Envelope --output "${OUTPUT}"
  { set +x; } 2>/dev/null
}

setAnchorPeer() {
    ORG=$1
    CORE_PEER_LOCALMSPID=Org${ORG}MSP
    HOST=PEER${ORG}_HOST
    export FABRIC_CFG_PATH=$PWD/config/org$ORG
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/tlsca/tlsca.org${ORG}.atgdigitals.com-cert.pem
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${ORG}.atgdigitals.com/users/Admin@org${ORG}.atgdigitals.com/msp
    export CORE_PEER_ADDRESS=${!HOST}:7051

    fetchChannelConfig $ORG $CHANNEL_NAME ${PWD}/channel-artifacts/${CORE_PEER_LOCALMSPID}config.json
    jq '.channel_group.groups.Application.groups.'${CORE_PEER_LOCALMSPID}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'peer0.org$ORG.atgdigitals.com'","port": '7051'}]},"version": "0"}}' ${PWD}/channel-artifacts/${CORE_PEER_LOCALMSPID}config.json > ${PWD}/channel-artifacts/${CORE_PEER_LOCALMSPID}modified_config.json
    res=$?
    { set +x; } 2>/dev/null
    verifyResult $res "Channel configuration update for anchor peer failed, make sure you have jq installed"

    createConfigUpdate ${CHANNEL_NAME} ${PWD}/channel-artifacts/${CORE_PEER_LOCALMSPID}config.json ${PWD}/channel-artifacts/${CORE_PEER_LOCALMSPID}modified_config.json ${PWD}/channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx
  
    ORDERER_CA=${PWD}/organizations/ordererOrganizations/org$ORG.atgdigitals.com/orderers/orderer$ORG.atgdigitals.com/tls/ca.crt
    $PWD/bin/fabric/peer channel update -o orderer$ORG.atgdigitals.com:7050 --ordererTLSHostnameOverride orderer$ORG.atgdigitals.com -c $CHANNEL_NAME -f ${PWD}/channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls --cafile "$ORDERER_CA" >> log.txt 2>&1
    res=$?
    cat log.txt
    verifyResult $res "Anchor peer update failed"
    echo "Anchor peer set for org '$CORE_PEER_LOCALMSPID' on channel '$CHANNEL_NAME'"
}

## Create channel genesis block
BLOCKFILE="$PWD/channel-artifacts/${CHANNEL_NAME}.block"

if [ ! -f "$BLOCKFILE" ]; then
  echo "Generating channel genesis block '${CHANNEL_NAME}.block'"
  export FABRIC_CFG_PATH=$PWD/config
  createChannelGenesisBlock 
fi 

## Create channel
echo "Creating channel ${CHANNEL_NAME}"
createChannel 1
createChannel 2
createChannel 3
echo "Channel '$CHANNEL_NAME' created"

## Join all the peers to the channel
echo "Joining org1 peer to the channel..."
export FABRIC_CFG_PATH=$PWD/config/org1
joinChannel 1
# echo "Joining org2 peer to the channel..."
export FABRIC_CFG_PATH=$PWD/config/org2
joinChannel 2
# echo "Joining org3 peer to the channel..."
export FABRIC_CFG_PATH=$PWD/config/org3
joinChannel 3

## Set the anchor peers for each org in the channel
echo "Setting anchor peer for org1..."
setAnchorPeer 1
# echo "Setting anchor peer for org2..."
setAnchorPeer 2

# echo "Setting anchor peer for org3..."
setAnchorPeer 3

echo "Channel '$CHANNEL_NAME' joined"

{ set +x; } 2>/dev/null
