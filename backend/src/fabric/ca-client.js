const FabricCAServices = require('fabric-ca-client');
const { Wallets } = require('fabric-network');
const path = require('path');
const fs = require('fs');

/**
 * Enroll the CA admin and store the identity in the wallet.
 * This must be done before registering/enrolling any other users.
 */
async function enrollCAAdmin(caURL, caName, mspId, walletPath) {
  const wallet = await Wallets.newFileSystemWallet(walletPath);

  const existing = await wallet.get('ca-admin');
  if (existing) {
    console.log(`CA admin already enrolled for ${caName}`);
    return wallet;
  }

  const ca = new FabricCAServices(caURL, { verify: false }, caName);
  const enrollment = await ca.enroll({ enrollmentID: 'admin', enrollmentSecret: 'adminpw' });

  const identity = {
    credentials: {
      certificate: enrollment.certificate,
      privateKey: enrollment.key.toBytes(),
    },
    mspId: mspId,
    type: 'X.509',
  };

  await wallet.put('ca-admin', identity);
  console.log(`CA admin enrolled for ${caName}`);
  return wallet;
}

/**
 * Enroll a user via Fabric CA and store the identity in the wallet.
 * If the user is already in the wallet, skip enrollment.
 */
async function enrollUser(caURL, caName, mspId, walletPath, username, secret) {
  const wallet = await Wallets.newFileSystemWallet(walletPath);

  const existing = await wallet.get(username);
  if (existing) {
    return wallet;
  }

  const ca = new FabricCAServices(caURL, { verify: false }, caName);

  // Request role and department attributes in the enrollment certificate
  const enrollment = await ca.enroll({
    enrollmentID: username,
    enrollmentSecret: secret,
    attr_reqs: [
      { name: 'role', optional: false },
      { name: 'department', optional: true },
    ],
  });

  const identity = {
    credentials: {
      certificate: enrollment.certificate,
      privateKey: enrollment.key.toBytes(),
    },
    mspId: mspId,
    type: 'X.509',
  };

  await wallet.put(username, identity);
  console.log(`User ${username} enrolled via ${caName}`);
  return wallet;
}

module.exports = { enrollCAAdmin, enrollUser };
