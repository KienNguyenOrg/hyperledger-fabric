#!/bin/bash

chmod +x $PWD/bin/chaincode/assetTransfer

sudo bash -c "systemctl restart fabric-gateway.service"
