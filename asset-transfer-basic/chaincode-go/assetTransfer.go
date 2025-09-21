/*
SPDX-License-Identifier: Apache-2.0
*/

package main

import (
	"fmt"
	"log"
	"os"
	"runtime/debug"

	"github.com/hyperledger/fabric-samples/asset-transfer-basic/chaincode-go/chaincode"

	"github.com/hyperledger/fabric-chaincode-go/v2/shim"
	"github.com/hyperledger/fabric-contract-api-go/v2/contractapi"
)

type LoggingSmartContract struct {
    *chaincode.SmartContract
}

func (l *LoggingSmartContract) BeforeTransaction(ctx contractapi.TransactionContextInterface) error {
    txID := ctx.GetStub().GetTxID()
    funcName, _ := ctx.GetStub().GetFunctionAndParameters()
    fmt.Printf("Incoming transaction: %s (TxID=%s)", funcName, txID)
    return nil
}

func main() {
	ccid := os.Getenv("CHAINCODE_ID")
	address := os.Getenv("CHAINCODE_SERVER_ADDRESS")

	if ccid == "" || address == "" {
		log.Panicf("CHAINCODE_ID and CHAINCODE_SERVER_ADDRESS must be set")
	}

	chaincodeInstance, err := contractapi.NewChaincode(&LoggingSmartContract{
		SmartContract: &chaincode.SmartContract{},
	})
	if err != nil {
		log.Panicf("Error creating chaincode: %s", err)
	}

	cc := shim.ChaincodeServer{
		CCID:    ccid,
		Address: address,
		CC:      chaincodeInstance,
		TLSProps: shim.TLSProperties{
			Disabled: true,
		},
	}

	fmt.Printf("Starting chaincode server at %s...\n", address)
	if err := cc.Start(); err != nil {
		log.Panicf("Error starting chaincode: %s", err)
		debug.PrintStack()
	}

}
