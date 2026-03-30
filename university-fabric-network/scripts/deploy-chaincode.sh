#!/bin/bash
# Deploy chaincode using Fabric 2.2 lifecycle

set -e

CHANNEL_NAME="universitychannel"
CC_NAME="student-ledger"
CC_VERSION="1.0"
CC_SEQUENCE=1
CC_SRC_PATH="/opt/gopath/src/github.com/chaincode/student-ledger"


echo \"Installing on University Peer\"

cd "$(dirname "$0")/.."

echo \"Downloading and vendoring Go dependencies\"
docker exec universitycli bash -c "cd $CC_SRC_PATH && GO111MODULE=on go mod tidy && go mod vendor"

echo \"Packaging chaincode\"
docker exec universitycli peer lifecycle chaincode package ${CC_NAME}.tar.gz \
  --path $CC_SRC_PATH \
  --lang golang \
  --label ${CC_NAME}_${CC_VERSION}

echo \"Installing chaincode\"
docker exec universitycli peer lifecycle chaincode install ${CC_NAME}.tar.gz

echo \"Querying installed chaincode\"
PACKAGE_ID_UNI=$(docker exec universitycli peer lifecycle chaincode queryinstalled 2>&1 | grep "${CC_NAME}_${CC_VERSION}" | sed -n 's/.*Package ID: \(.*\), Label.*/\1/p')
echo "Package ID: $PACKAGE_ID_UNI"

if [ -z "$PACKAGE_ID_UNI" ]; then
  echo "ERROR: Failed to get package ID"
  exit 1
fi

echo \"Approving chaincode for org\"
docker exec universitycli peer lifecycle chaincode approveformyorg \
  -o orderer.university.com:7050 \
  --channelID $CHANNEL_NAME \
  --name $CC_NAME \
  --version $CC_VERSION \
  --package-id $PACKAGE_ID_UNI \
  --sequence $CC_SEQUENCE  

echo \"Checking commit readiness\"
docker exec universitycli peer lifecycle chaincode checkcommitreadiness \
  --channelID $CHANNEL_NAME \
  --name $CC_NAME \
  --version $CC_VERSION \
  --sequence $CC_SEQUENCE \
  --output json



echo \"Installing on Department Peer\"

cd "$(dirname "$0")/.."

echo \"Downloading and vendoring Go dependencies\"
docker exec departmentcli bash -c "cd $CC_SRC_PATH && GO111MODULE=on go mod tidy && go mod vendor"

echo \"Packaging chaincode\"
docker exec departmentcli peer lifecycle chaincode package ${CC_NAME}.tar.gz \
  --path $CC_SRC_PATH \
  --lang golang \
  --label ${CC_NAME}_${CC_VERSION}

echo \"Installing chaincode\"
docker exec departmentcli peer lifecycle chaincode install ${CC_NAME}.tar.gz

echo \"Querying installed chaincode\"
PACKAGE_ID_DEPT=$(docker exec departmentcli peer lifecycle chaincode queryinstalled 2>&1 | grep "${CC_NAME}_${CC_VERSION}" | sed -n 's/.*Package ID: \(.*\), Label.*/\1/p')
echo "Package ID: $PACKAGE_ID_DEPT"

if [ -z "$PACKAGE_ID_DEPT" ]; then
  echo "ERROR: Failed to get package ID"
  exit 1
fi

echo \"Approving chaincode for org\"
docker exec departmentcli peer lifecycle chaincode approveformyorg \
  -o orderer.university.com:7050 \
  --channelID $CHANNEL_NAME \
  --name $CC_NAME \
  --version $CC_VERSION \
  --package-id $PACKAGE_ID_DEPT \
  --sequence $CC_SEQUENCE  

echo \"Checking commit readiness\"
docker exec departmentcli peer lifecycle chaincode checkcommitreadiness \
  --channelID $CHANNEL_NAME \
  --name $CC_NAME \
  --version $CC_VERSION \
  --sequence $CC_SEQUENCE \
  --output json


sleep 2

echo \"Committing chaincode\"
docker exec departmentcli peer lifecycle chaincode commit \
  -o orderer.university.com:7050 \
  --channelID $CHANNEL_NAME \
  --name $CC_NAME \
  --version $CC_VERSION \
  --sequence $CC_SEQUENCE \
  --peerAddresses peer0.department.university.edu:9051 \
  --peerAddresses peer0.university.edu:7051

echo \"Verifying committed chaincode\"
docker exec universitycli peer lifecycle chaincode querycommitted \
  --channelID $CHANNEL_NAME \
  --name $CC_NAME

echo \"Chaincode deployed successfully\"
