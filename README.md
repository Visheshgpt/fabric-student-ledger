# University Student Ledger 

This is an implementation of a blockchain application that tracks student activities in a university, such as paying fees, borrowing library books, and exam registrations. 
It is built using Hyperledger Fabric 2.2.

**Fabric CA** is used to generate all certificates and handle identity management. Attribute-Based Access Control (ABAC) is implemented to ensure staff members can only perform actions they have permission for based on their department.

## Tech Stack
- Hyperledger Fabric 2.2 (using a solo orderer and 2 peers across two orgs: UniversityOrg and DepartmentOrg)
- Fabric CA for certificate generation
- Go for the chaincode
- Node.js and Express for backend REST apis
- React for the frontend UI

## Network Topology & Folder Structure

The fabric network topology is designed as follows:
```text
universitychannel
├── OrdererOrg (Solo orderer :7050)
├── UniversityOrg
│   ├── peer0 :7051
│   ├── ca    :7054
│   └── Users (admin1, registrar1)
└── DepartmentOrg
    ├── peer0 :9051
    ├── ca    :8054
    └── Users (cs-staff1, finance1, etc)
```
There are two main organizations (plus the orderer). Both orgs need to endorse a transaction before it gets committed to the ledger (Majority policy).

Here is the folder structure for the project:
```text
poc-fabric/
├── backend/                  # Node.js REST api
├── frontend/                 # React UI
├── explorer/                 # Hyperledger Explorer config
├── README.md                 
└── university-fabric-network/
    ├── base/                 # docker base configs
    ├── chaincode/            # go smart contract
    ├── configtx.yaml         
    ├── docker-compose-ca.yaml # to run the 3 CAs
    ├── docker-compose.yaml    # to run peers/orderer
    └── scripts/
        ├── deploy-chaincode.sh
        ├── register-ca-users.sh
        ├── start-ca-network.sh # the main setup script
        └── stop-network.sh
```

## How the access control works
When users are registered in the system, they are assigned a `role` and a `department`. This gets embedded right into their X.509 certificate by the CA. 
The smart contract (chaincode) checks these attributes before writing to the ledger:
- `admin` can do pretty much anything.
- `registrar` can register new students and add exam records.
- `staff` permissions depend on their department. For example a CS staff can only add exam records for students who are in the CS department. A finance staff can add fee records for any student.

## How to run the project

Make sure you have Docker, Node.js and the Fabric v2.2 binaries installed on your computer. 
If you don't have the fabric binaries, you can download them using:
```bash
curl -sSL https://bit.ly/2ysbOFE | bash -s -- 2.2.0 1.4.9
```
After running that, make sure to copy the `bin` folder into your `university-fabric-network` directory if it's not already there. You can delete the `fabric-samples` folder that this command creates.

You also need to make sure those downloaded Fabric binaries are inside your `PATH` so the setup script can find them. You can do this by running:
```bash
export PATH=$PWD/bin:$PATH
```


### 1. Start the fabric network
Go into the network folder, make the scripts executable, and run the setup script.
```bash
cd university-fabric-network
chmod +x scripts/*.sh
./scripts/start-ca-network.sh
```
What this script does is basically start 3 CA servers first. Then it enrolls all the admins, peers, and users. After building the crypto-config tree, it starts the actual orderer and peer containers, creates the channel `universitychannel`, and finally deploys the chaincode.

### 2. Start the Backend API
Open a new terminal and run:
```bash
cd backend
npm install
npm start
```
The backend API exposes endpoints on port 3001. It uses per-user wallets, meaning it will enroll whatever user you pass in the headers and use their specific identity to talk to the blockchain.

### 3. Start the Frontend
In another terminal run:
```bash
cd frontend
npm install
npm start
```
The React app will open on `http://localhost:3000`. 
A dropdown is available at the top to easily switch between different users (like admin1 or cs-staff1) to test the ABAC permissions without requiring an actual login.

## API Flow (Testing with Curl)

If you don't really want to use the frontend React app, you can completely test the flow using curl commands against the backend port 3001. All endpoints check the `X-User` header to know which wallet identity to perform the action with.

List the users you can authenticate as:
```bash
curl http://localhost:3001/api/auth/users
```

Register a new student (using registrar1 account):
```bash
curl -X POST http://localhost:3001/api/students/register \
  -H "Content-Type: application/json" \
  -H "X-User: registrar1" \
  -d '{"id": "S001", "name": "Bob Smith", "department": "CS"}'
```

Add an exam registration for that student (must use a CS staff account because Bob is in CS!):
```bash
curl -X POST http://localhost:3001/api/students/activity \
  -H "Content-Type: application/json" \
  -H "X-User: cs-staff1" \
  -d '{"id": "S001", "type": "exam", "details": "Registered for intro to algorithms"}'
```

You can also submit other types of activities, like library or fee payments, just make sure you use a user who has permission.
```bash
curl -X POST http://localhost:3001/api/students/activity \
  -H "Content-Type: application/json" \
  -H "X-User: library1" \
  -d '{"id": "S001", "type": "library", "details": "Rented a physics textbook"}'
```

Get the student's full current data block from the ledger (anyone can query):
```bash
curl http://localhost:3001/api/students/S001
```

Get all students in a particular department (this uses a composite key query):
```bash
curl http://localhost:3001/api/students/department/CS
```

Check the entire immutable transaction history for the student (only admin or registrar can track history):
```bash
curl -H "X-User: admin1" http://localhost:3001/api/students/S001/history
```

## Stopping everything
To bring the network down and clean all the generated crypto files or wallets, just run:
```bash
cd university-fabric-network
./scripts/stop-network.sh
```
