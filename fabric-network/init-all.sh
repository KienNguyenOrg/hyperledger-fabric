#!/bin/bash

. utils.sh

USERNAME=$1
WORKING_DIR=$2

# Cleanup all data and re-initialize the network

ssh $USERNAME@peer0.org2.atgdigitals.com "sudo rm -rf $WORKING_DIR/hyperledger && mkdir -p $WORKING_DIR/hyperledger/fabric-network"
scp -r $WORKING_DIR/hyperledger/fabric-network $USERNAME@peer0.org2.atgdigitals.com:$WORKING_DIR/hyperledger
ssh $USERNAME@peer0.org3.atgdigitals.com "sudo rm -rf $WORKING_DIR/hyperledger && mkdir -p $WORKING_DIR/hyperledger/fabric-network"
scp -r $WORKING_DIR/hyperledger/fabric-network $USERNAME@peer0.org3.atgdigitals.com:$WORKING_DIR/hyperledger

# Setup environment
runAsRoot       ./00.setup.sh
ssh $USERNAME@peer0.org2.atgdigitals.com "cd $WORKING_DIR/hyperledger/fabric-network && sudo bash ./00.setup.sh"
ssh $USERNAME@peer0.org3.atgdigitals.com "cd $WORKING_DIR/hyperledger/fabric-network && sudo bash ./00.setup.sh"

# Initialize TLS CA servers
runAsRoot       ./02.start_tls_ca_server.sh stop
runAsRoot       ./04.start_peer_and_ordering.sh stop org1
ssh $USERNAME@peer0.org2.atgdigitals.com "cd $WORKING_DIR/hyperledger/fabric-network && sudo ./04.start_peer_and_ordering.sh stop org2"
ssh $USERNAME@peer0.org3.atgdigitals.com "cd $WORKING_DIR/hyperledger/fabric-network && sudo ./04.start_peer_and_ordering.sh stop org3"
runAsRoot       ./04.start_peer_and_ordering.sh stop orderer
sudo            ./00.cleanup.sh
./01.init_tls_ca_server.sh all
runAsRoot       ./02.start_tls_ca_server.sh start
./03.enroll_servers.sh
runAsRoot       ./02.start_tls_ca_server.sh stop

# Copy files to peer0.org2 and peer0.org3
scp -r ./organizations $USERNAME@peer0.org2.atgdigitals.com:$WORKING_DIR/hyperledger/fabric-network
scp -r ./organizations $USERNAME@peer0.org3.atgdigitals.com:$WORKING_DIR/hyperledger/fabric-network

# Start all servers
runAsRoot       ./04.start_peer_and_ordering.sh start org1 
ssh $USERNAME@peer0.org2.atgdigitals.com "cd $WORKING_DIR/hyperledger/fabric-network && sudo bash ./04.start_peer_and_ordering.sh start org2"
ssh $USERNAME@peer0.org3.atgdigitals.com "cd $WORKING_DIR/hyperledger/fabric-network && sudo bash ./04.start_peer_and_ordering.sh start org3"
runAsRoot       ./04.start_peer_and_ordering.sh start orderer 

scp $USERNAME@peer0.org2.atgdigitals.com:$WORKING_DIR/hyperledger/fabric-network/config/org2/core.yaml $WORKING_DIR/hyperledger/fabric-network/config/org2/core.yaml
scp $USERNAME@peer0.org3.atgdigitals.com:$WORKING_DIR/hyperledger/fabric-network/config/org3/core.yaml $WORKING_DIR/hyperledger/fabric-network/config/org3/core.yaml
mv ./organizations/peerOrganizations/org2.atgdigitals.com/users/Admin@org2.atgdigitals.com/msp/cacerts/peer0-org1-atgdigitals-com-9054.pem ./organizations/peerOrganizations/org2.atgdigitals.com/users/Admin@org2.atgdigitals.com/msp/cacerts/peer0-org2-atgdigitals-com-9054.pem
mv ./organizations/peerOrganizations/org3.atgdigitals.com/users/Admin@org3.atgdigitals.com/msp/cacerts/peer0-org1-atgdigitals-com-10054.pem ./organizations/peerOrganizations/org3.atgdigitals.com/users/Admin@org3.atgdigitals.com/msp/cacerts/peer0-org3-atgdigitals-com-10054.pem

# Create channel and deploy chaincode
./05.create_channel.sh orderer.atgdigitals.com peer0.org1.atgdigitals.com peer0.org2.atgdigitals.com peer0.org3.atgdigitals.com
./06.deploy_chaincode.sh ../asset-transfer-basic/chaincode-go peer0.org1.atgdigitals.com peer0.org2.atgdigitals.com peer0.org3.atgdigitals.com $USERNAME $WORKING_DIR

# Start api service
./07.start_gateway.sh
