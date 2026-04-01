const { Gateway, Wallets } = require('fabric-network');
const path = require('path');
const { enrollUser } = require('./ca-client');

const CHANNEL_NAME = process.env.CHANNEL_NAME || 'universitychannel';
const CHAINCODE_NAME = process.env.CHAINCODE_NAME || 'student-ledger';

// Org configs
const orgs = {
  university: {
    mspId: process.env.UNIVERSITY_MSP_ID || 'UniversityMSP',
    peerEndpoint: process.env.UNIVERSITY_PEER_ENDPOINT || 'grpc://localhost:7051',
    peerName: 'peer0.university.edu',
    caURL: process.env.UNIVERSITY_CA_URL || 'http://localhost:7054',
    caName: process.env.UNIVERSITY_CA_NAME || 'ca-university',
  },
  department: {
    mspId: process.env.DEPARTMENT_MSP_ID || 'DepartmentMSP',
    peerEndpoint: process.env.DEPARTMENT_PEER_ENDPOINT || 'grpc://localhost:9051',
    peerName: 'peer0.department.university.edu',
    caURL: process.env.DEPARTMENT_CA_URL || 'http://localhost:8054',
    caName: process.env.DEPARTMENT_CA_NAME || 'ca-department',
  },
};

// Map of predefined users to their org and secrets
const userRegistry = {
  admin1:       { org: 'university', secret: 'admin1pw',      role: 'admin',     department: '' },
  registrar1:   { org: 'university', secret: 'registrar1pw',  role: 'registrar', department: '' },
  'cs-staff1':  { org: 'department', secret: 'cs-staff1pw',   role: 'staff',     department: 'CS' },
  'ee-staff1':  { org: 'department', secret: 'ee-staff1pw',   role: 'staff',     department: 'EE' },
  finance1:     { org: 'department', secret: 'finance1pw',    role: 'staff',     department: 'finance' },
  library1:     { org: 'department', secret: 'library1pw',    role: 'staff',     department: 'library' },
};

// build connection profile with both peers so we can get endorsements from both orgs (majority policy)
function buildConnectionProfile(orgKey) {
  const clientOrg = orgKey === 'university' ? 'UniversityOrg' : 'DepartmentOrg';
  return {
    name: 'university-network',
    version: '1.0.0',
    client: { organization: clientOrg },
    organizations: {
      UniversityOrg: {
        mspid: orgs.university.mspId,
        peers: [orgs.university.peerName],
      },
      DepartmentOrg: {
        mspid: orgs.department.mspId,
        peers: [orgs.department.peerName],
      },
    },
    peers: {
      [orgs.university.peerName]: {
        url: orgs.university.peerEndpoint,
      },
      [orgs.department.peerName]: {
        url: orgs.department.peerEndpoint,
      },
    },
  };
}

// helper to get the wallet path
function getWalletPath(orgKey) {
  return path.join(__dirname, '..', '..', 'wallet', orgKey);
}

// connect to network using a specific user 
// enrolls via CA if not already in wallet
async function getContract(username) {
  const userInfo = userRegistry[username];
  if (!userInfo) {
    throw new Error(`Unknown user: ${username}. Valid users: ${Object.keys(userRegistry).join(', ')}`);
  }

  const orgKey = userInfo.org;
  const org = orgs[orgKey];
  const walletPath = getWalletPath(orgKey);

  // Enroll user via Fabric CA (creates wallet identity if not exists)
  const wallet = await enrollUser(org.caURL, org.caName, org.mspId, walletPath, username, userInfo.secret);

  const identity = await wallet.get(username);
  if (!identity) {
    throw new Error(`Identity ${username} not found in wallet. Ensure CA is running and users are registered.`);
  }

  const ccp = buildConnectionProfile(orgKey);
  const gateway = new Gateway();
  await gateway.connect(ccp, {
    wallet,
    identity: username,
    discovery: { enabled: true, asLocalhost: true },
  });

  const network = await gateway.getNetwork(CHANNEL_NAME);
  const contract = network.getContract(CHAINCODE_NAME);

  return { gateway, contract };
}

// get user list for the frontend selector
function getAvailableUsers() {
  return Object.entries(userRegistry).map(([username, info]) => ({
    username,
    role: info.role,
    department: info.department,
    org: info.org === 'university' ? 'UniversityOrg' : 'DepartmentOrg',
  }));
}

module.exports = { getContract, getAvailableUsers, userRegistry };
