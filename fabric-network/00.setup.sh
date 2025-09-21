#!/bin/bash

. ./utils.sh

set -x

sudo cp $PWD/systemd/*/*.service  /etc/systemd/system/

sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-ca-ordererOrg1.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-ca-ordererOrg2.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-ca-ordererOrg3.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-ca-org1.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-ca-org2.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-ca-org3.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-ordering1.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-ordering2.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-ordering3.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-peer-org1.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-peer-org2.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-peer-org3.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-chaincode.service
sudo sed -i "s|\$PWD|$PWD|g" /etc/systemd/system/fabric-gateway.service
sudo sed -i "s|fabric-network/application-gateway-go|asset-transfer-basic/application-gateway-go|" /etc/systemd/system/fabric-gateway.service

sudo bash -c "systemctl daemon-reload"

chmod +x $PWD/bin/*
chmod +x $PWD/builders/*

{ set +x; } 2>/dev/null
