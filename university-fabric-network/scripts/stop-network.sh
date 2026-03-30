#!/bin/bash
# Stop and clean up the Fabric network (including Fabric CA servers)

set -e

cd "$(dirname "$0")/.."

echo \"Stopping Docker containers\"
docker compose -f docker-compose.yaml down --volumes --remove-orphans 2>/dev/null || true
docker compose -f docker-compose-ca.yaml down --volumes --remove-orphans 2>/dev/null || true

docker stop $(docker ps -a -q) 2>/dev/null || true
docker rm $(docker ps -a -q) 2>/dev/null || true

# Remove all networks
echo "Removing all networks..."
docker network rm $(docker network ls -q) 2>/dev/null || true
docker network prune -f

# Remove ALL Hyperledger volumes
echo "Removing all Hyperledger volumes..."
docker volume rm $(docker volume ls -q | grep -E '(net_|orderer|peer|org|example|com|edu)') 2>/dev/null || true
docker volume prune -f

echo \"Removing generated crypto material\"
rm -rf crypto-config/ordererOrganizations
rm -rf crypto-config/peerOrganizations
rm -rf channel-artifacts/*.block channel-artifacts/*.tx

echo \"Removing CA server data\"
rm -rf ca-server
rm -rf ca-client

echo \"Removing chaincode Docker images\"
docker images -q "dev-peer*" 2>/dev/null | xargs -r docker rmi -f

echo \"Network stopped and cleaned\"
