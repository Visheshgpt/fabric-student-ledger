#!/bin/bash
# Fabric CA Network Setup
# This script generates ALL crypto material through Fabric CA servers.
# It starts CAs, enrolls orderer/peers/admins/users, builds the MSP directory
# tree, generates channel artifacts, and deploys the chaincode.

set -e

cd "$(dirname "$0")/.."
export FABRIC_CFG_PATH=$PWD
export PATH=$PWD/bin:$PATH

CHANNEL_NAME="universitychannel"
CC_NAME="student-ledger"
CC_VERSION="1.0"
CC_SEQUENCE=1
CC_SRC_PATH="/opt/gopath/src/github.com/chaincode/student-ledger"

ORDERER_CA_PORT=9054
UNIVERSITY_CA_PORT=7054
DEPARTMENT_CA_PORT=8054

# Helper: Write NodeOUs config.yaml into an MSP directory
function writeNodeOUConfig() {
  local msp_dir=$1
  # Find the CA cert filename (auto-generated name like localhost-7054-ca-university.pem)
  local ca_cert_file
  ca_cert_file=$(ls "${msp_dir}/cacerts/"*.pem 2>/dev/null | head -1)
  local ca_cert_name
  ca_cert_name=$(basename "$ca_cert_file")

  cat > "${msp_dir}/config.yaml" << YAML
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/${ca_cert_name}
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/${ca_cert_name}
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/${ca_cert_name}
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/${ca_cert_name}
    OrganizationalUnitIdentifier: orderer
YAML
}


# 1. CLEANUP
echo \"Cleaning up old network\"
docker compose -f docker-compose.yaml down --volumes --remove-orphans 2>/dev/null || true
docker compose -f docker-compose-ca.yaml down --volumes --remove-orphans 2>/dev/null || true
docker rm -f $(docker ps -aq --filter "name=dev-peer*") 2>/dev/null || true
docker rmi -f $(docker images -q "dev-peer*") 2>/dev/null || true
rm -rf crypto-config ca-server ca-client
rm -f channel-artifacts/*.block channel-artifacts/*.tx
echo "Cleanup done."


# 2. START FABRIC CA SERVERS
echo ""
echo \"Starting Fabric CA servers\"
docker compose -f docker-compose-ca.yaml up -d

echo "Waiting for CAs to start..."
sleep 5


# 3. ORDERER ORG — Enroll orderer identity via CA
echo ""
echo \"Setting up OrdererOrg (via ca-orderer on port ${ORDERER_CA_PORT})\"

# Working directory for CA client operations against orderer CA
export FABRIC_CA_CLIENT_HOME=$PWD/ca-client/orderer
echo "$FABRIC_CA_CLIENT_HOME"
mkdir -p $FABRIC_CA_CLIENT_HOME

# 3a. Enroll the CA bootstrap admin
fabric-ca-client enroll \
  -u http://admin:adminpw@localhost:${ORDERER_CA_PORT} \
  --caname ca-orderer

# 3b. Register the orderer node identity (type=orderer)
fabric-ca-client register --caname ca-orderer \
  --id.name orderer.university.com --id.secret ordererpw --id.type orderer

# 3c. Register an admin user for OrdererOrg (type=admin)
fabric-ca-client register --caname ca-orderer \
  --id.name ordererAdmin --id.secret ordererAdminpw --id.type admin

# 3d. Enroll orderer node → put MSP in crypto-config directory
ORDERER_NODE_MSP=crypto-config/ordererOrganizations/university.com/orderers/orderer.university.com/msp
fabric-ca-client enroll \
  -u http://orderer.university.com:ordererpw@localhost:${ORDERER_CA_PORT} \
  --caname ca-orderer \
  -M $PWD/${ORDERER_NODE_MSP}
writeNodeOUConfig ${ORDERER_NODE_MSP}

# 3e. Build org-level MSP (cacerts + config.yaml — used by configtxgen)
ORDERER_ORG_MSP=crypto-config/ordererOrganizations/university.com/msp
mkdir -p ${ORDERER_ORG_MSP}/cacerts
cp ${ORDERER_NODE_MSP}/cacerts/* ${ORDERER_ORG_MSP}/cacerts/
writeNodeOUConfig ${ORDERER_ORG_MSP}

echo "  ✓ OrdererOrg MSP created"


# 4. UNIVERSITY ORG — Enroll peer, admin, and application users
echo ""
echo \"Setting up UniversityOrg (via ca-university on port ${UNIVERSITY_CA_PORT})\"

export FABRIC_CA_CLIENT_HOME=$PWD/ca-client/university
mkdir -p $FABRIC_CA_CLIENT_HOME

# 4a. Enroll CA bootstrap admin
fabric-ca-client enroll \
  -u http://admin:adminpw@localhost:${UNIVERSITY_CA_PORT} \
  --caname ca-university

# 4b. Register identities
fabric-ca-client register --caname ca-university \
  --id.name peer0.university.edu --id.secret peer0pw --id.type peer

fabric-ca-client register --caname ca-university \
  --id.name universityadmin --id.secret universityadminpw --id.type admin

fabric-ca-client register --caname ca-university \
  --id.name admin1 --id.secret admin1pw --id.type client \
  --id.attrs "role=admin:ecert"

fabric-ca-client register --caname ca-university \
  --id.name registrar1 --id.secret registrar1pw --id.type client \
  --id.attrs "role=registrar:ecert"

# 4c. Enroll peer0 → node MSP
PEER0_UNI_MSP=crypto-config/peerOrganizations/university.edu/peers/peer0.university.edu/msp
fabric-ca-client enroll \
  -u http://peer0.university.edu:peer0pw@localhost:${UNIVERSITY_CA_PORT} \
  --caname ca-university \
  -M $PWD/${PEER0_UNI_MSP}
writeNodeOUConfig ${PEER0_UNI_MSP}

# 4d. Enroll org admin → user MSP (mounted by CLI container)
ADMIN_UNI_MSP=crypto-config/peerOrganizations/university.edu/users/Admin@university.edu/msp
fabric-ca-client enroll \
  -u http://universityadmin:universityadminpw@localhost:${UNIVERSITY_CA_PORT} \
  --caname ca-university \
  -M $PWD/${ADMIN_UNI_MSP}
writeNodeOUConfig ${ADMIN_UNI_MSP}

# 4e. Build org-level MSP (for configtxgen)
UNI_ORG_MSP=crypto-config/peerOrganizations/university.edu/msp
mkdir -p ${UNI_ORG_MSP}/cacerts
cp ${PEER0_UNI_MSP}/cacerts/* ${UNI_ORG_MSP}/cacerts/
writeNodeOUConfig ${UNI_ORG_MSP}

# 4f. Copy CA cert for backward compatibility (explorer etc.)
mkdir -p crypto-config/peerOrganizations/university.edu/ca
cp ${PEER0_UNI_MSP}/cacerts/* crypto-config/peerOrganizations/university.edu/ca/

echo "  ✓ UniversityOrg MSP created (peer0, admin, admin1, registrar1 registered)"


# 5. DEPARTMENT ORG — Enroll peer, admin, and department staff users
echo ""
echo \"Setting up DepartmentOrg (via ca-department on port ${DEPARTMENT_CA_PORT})\"

export FABRIC_CA_CLIENT_HOME=$PWD/ca-client/department
mkdir -p $FABRIC_CA_CLIENT_HOME

# 5a. Enroll CA bootstrap admin
fabric-ca-client enroll \
  -u http://admin:adminpw@localhost:${DEPARTMENT_CA_PORT} \
  --caname ca-department

# 5b. Register identities
fabric-ca-client register --caname ca-department \
  --id.name peer0.department.university.edu --id.secret peer0pw --id.type peer

fabric-ca-client register --caname ca-department \
  --id.name departmentadmin --id.secret departmentadminpw --id.type admin

fabric-ca-client register --caname ca-department \
  --id.name cs-staff1 --id.secret cs-staff1pw --id.type client \
  --id.attrs "role=staff:ecert,department=CS:ecert"

fabric-ca-client register --caname ca-department \
  --id.name ee-staff1 --id.secret ee-staff1pw --id.type client \
  --id.attrs "role=staff:ecert,department=EE:ecert"

fabric-ca-client register --caname ca-department \
  --id.name finance1 --id.secret finance1pw --id.type client \
  --id.attrs "role=staff:ecert,department=finance:ecert"

fabric-ca-client register --caname ca-department \
  --id.name library1 --id.secret library1pw --id.type client \
  --id.attrs "role=staff:ecert,department=library:ecert"

# 5c. Enroll peer0 → node MSP
PEER0_DEPT_MSP=crypto-config/peerOrganizations/department.university.edu/peers/peer0.department.university.edu/msp
fabric-ca-client enroll \
  -u http://peer0.department.university.edu:peer0pw@localhost:${DEPARTMENT_CA_PORT} \
  --caname ca-department \
  -M $PWD/${PEER0_DEPT_MSP}
writeNodeOUConfig ${PEER0_DEPT_MSP}

# 5d. Enroll org admin → user MSP (mounted by CLI container)
ADMIN_DEPT_MSP=crypto-config/peerOrganizations/department.university.edu/users/Admin@department.university.edu/msp
fabric-ca-client enroll \
  -u http://departmentadmin:departmentadminpw@localhost:${DEPARTMENT_CA_PORT} \
  --caname ca-department \
  -M $PWD/${ADMIN_DEPT_MSP}
writeNodeOUConfig ${ADMIN_DEPT_MSP}

# 5e. Build org-level MSP (for configtxgen)
DEPT_ORG_MSP=crypto-config/peerOrganizations/department.university.edu/msp
mkdir -p ${DEPT_ORG_MSP}/cacerts
cp ${PEER0_DEPT_MSP}/cacerts/* ${DEPT_ORG_MSP}/cacerts/
writeNodeOUConfig ${DEPT_ORG_MSP}

# 5f. Copy CA cert for backward compatibility
mkdir -p crypto-config/peerOrganizations/department.university.edu/ca
cp ${PEER0_DEPT_MSP}/cacerts/* crypto-config/peerOrganizations/department.university.edu/ca/

echo "  ✓ DepartmentOrg MSP created (peer0, admin, cs-staff1, ee-staff1, finance1, library1 registered)"


# 6. GENERATE CHANNEL ARTIFACTS (uses the MSP tree we just built)
echo ""
echo \"Generating genesis block\"
sleep 5
mkdir -p channel-artifacts
configtxgen -profile UniversityGenesis \
  -channelID system-channel \
  -outputBlock ./channel-artifacts/genesis.block

echo ""
echo \"Generating channel transaction\"
configtxgen -profile UniversityChannel \
  -outputCreateChannelTx ./channel-artifacts/channel.tx \
  -channelID $CHANNEL_NAME

echo ""
echo \"Generating anchor peer updates\"
configtxgen -profile UniversityChannel \
  -channelID $CHANNEL_NAME \
  -outputAnchorPeersUpdate ./channel-artifacts/UniversityMSPanchors.tx \
  -asOrg UniversityOrg

configtxgen -profile UniversityChannel \
  -channelID $CHANNEL_NAME \
  -outputAnchorPeersUpdate ./channel-artifacts/DepartmentMSPanchors.tx \
  -asOrg DepartmentOrg


# 7. START ORDERER, PEERS, CLI CONTAINERS
echo ""
echo \"Starting network containers (orderer, peers, CLI)\"
docker compose -f docker-compose.yaml up -d

echo "Waiting for containers to start..."
sleep 5


# 8. CREATE & JOIN CHANNEL
echo ""
echo \"Creating channel\"
docker exec universitycli peer channel create \
  -o orderer.university.com:7050 \
  -c ${CHANNEL_NAME} \
  -f ./channel-artifacts/channel.tx \
  --outputBlock ./channel-artifacts/${CHANNEL_NAME}.block

echo ""
echo \"Joining peers to channel\"
docker exec universitycli peer channel join \
  -b ./channel-artifacts/${CHANNEL_NAME}.block
sleep 3
docker exec departmentcli peer channel join \
  -b ./channel-artifacts/${CHANNEL_NAME}.block

echo ""
echo \"Updating anchor peers\"
docker exec universitycli peer channel update \
  -o orderer.university.com:7050 \
  -c $CHANNEL_NAME \
  -f ./channel-artifacts/UniversityMSPanchors.tx
sleep 3
docker exec departmentcli peer channel update \
  -o orderer.university.com:7050 \
  -c $CHANNEL_NAME \
  -f ./channel-artifacts/DepartmentMSPanchors.tx


# 9. DEPLOY CHAINCODE (Fabric v2.2 Lifecycle — both peers)
echo ""
echo \"Deploying chaincode on University Peer\"
docker exec universitycli bash -c "cd $CC_SRC_PATH && GO111MODULE=on go mod tidy && go mod vendor"
docker exec universitycli peer lifecycle chaincode package ${CC_NAME}.tar.gz \
  --path $CC_SRC_PATH --lang golang --label ${CC_NAME}_${CC_VERSION}
docker exec universitycli peer lifecycle chaincode install ${CC_NAME}.tar.gz

PACKAGE_ID_UNI=$(docker exec universitycli peer lifecycle chaincode queryinstalled 2>&1 | grep "${CC_NAME}_${CC_VERSION}" | sed -n 's/.*Package ID: \(.*\), Label.*/\1/p')
echo "  University Package ID: $PACKAGE_ID_UNI"

if [ -z "$PACKAGE_ID_UNI" ]; then
  echo "ERROR: Failed to get package ID for University peer"
  exit 1
fi

docker exec universitycli peer lifecycle chaincode approveformyorg \
  -o orderer.university.com:7050 --channelID $CHANNEL_NAME \
  --name $CC_NAME --version $CC_VERSION --package-id $PACKAGE_ID_UNI --sequence $CC_SEQUENCE

echo ""
echo \"Deploying chaincode on Department Peer\"
docker exec departmentcli bash -c "cd $CC_SRC_PATH && GO111MODULE=on go mod tidy && go mod vendor"
docker exec departmentcli peer lifecycle chaincode package ${CC_NAME}.tar.gz \
  --path $CC_SRC_PATH --lang golang --label ${CC_NAME}_${CC_VERSION}
docker exec departmentcli peer lifecycle chaincode install ${CC_NAME}.tar.gz

PACKAGE_ID_DEPT=$(docker exec departmentcli peer lifecycle chaincode queryinstalled 2>&1 | grep "${CC_NAME}_${CC_VERSION}" | sed -n 's/.*Package ID: \(.*\), Label.*/\1/p')
echo "  Department Package ID: $PACKAGE_ID_DEPT"

if [ -z "$PACKAGE_ID_DEPT" ]; then
  echo "ERROR: Failed to get package ID for Department peer"
  exit 1
fi

docker exec departmentcli peer lifecycle chaincode approveformyorg \
  -o orderer.university.com:7050 --channelID $CHANNEL_NAME \
  --name $CC_NAME --version $CC_VERSION --package-id $PACKAGE_ID_DEPT --sequence $CC_SEQUENCE

sleep 2

echo ""
echo \"Committing chaincode\"
docker exec departmentcli peer lifecycle chaincode commit \
  -o orderer.university.com:7050 --channelID $CHANNEL_NAME \
  --name $CC_NAME --version $CC_VERSION --sequence $CC_SEQUENCE \
  --peerAddresses peer0.department.university.edu:9051 \
  --peerAddresses peer0.university.edu:7051

echo ""
echo \"Verifying committed chaincode\"
docker exec universitycli peer lifecycle chaincode querycommitted \
  --channelID $CHANNEL_NAME --name $CC_NAME


# DONE
echo ""
echo \"\"
echo "  ✅ Network is UP!"
echo ""
echo "  Orderer:         localhost:7050"
echo "  University Peer: localhost:7051"
echo "  Department Peer: localhost:9051"
echo ""
echo "  Orderer CA:      localhost:${ORDERER_CA_PORT}"
echo "  University CA:   localhost:${UNIVERSITY_CA_PORT}"
echo "  Department CA:   localhost:${DEPARTMENT_CA_PORT}"
echo ""
echo "  Channel:         ${CHANNEL_NAME}"
echo "  Chaincode:       ${CC_NAME}"
echo ""
echo "  Registered Users (with ABAC attributes):"
echo "    UniversityOrg:"
echo "      admin1     (role=admin)"
echo "      registrar1 (role=registrar)"
echo "    DepartmentOrg:"
echo "      cs-staff1  (role=staff, department=CS)"
echo "      ee-staff1  (role=staff, department=EE)"
echo "      finance1   (role=staff, department=finance)"
echo "      library1   (role=staff, department=library)"
echo \"\"
