#!/bin/bash
# Register application users with Fabric CA (standalone)
# Use this script to register additional users AFTER the network is running.
# The start-ca-network.sh already registers the default set of users.
# This script is useful if you need to re-register or add new users.

set -e

cd "$(dirname "$0")/.."

UNIVERSITY_CA_PORT=7054
DEPARTMENT_CA_PORT=8054

echo ""
echo \"Registering University Org application users\"

export FABRIC_CA_CLIENT_HOME=$PWD/ca-client/university

# Ensure CA admin is enrolled
if [ ! -d "$FABRIC_CA_CLIENT_HOME/msp" ]; then
  echo "Enrolling University CA admin..."
  fabric-ca-client enroll -u http://admin:adminpw@localhost:${UNIVERSITY_CA_PORT} --caname ca-university
fi

# Admin user
fabric-ca-client register --caname ca-university \
  --id.name admin1 --id.secret admin1pw --id.type client \
  --id.attrs "role=admin:ecert" \
  2>/dev/null && echo "  ✓ admin1 registered" || echo "  → admin1 already registered"

# Registrar user
fabric-ca-client register --caname ca-university \
  --id.name registrar1 --id.secret registrar1pw --id.type client \
  --id.attrs "role=registrar:ecert" \
  2>/dev/null && echo "  ✓ registrar1 registered" || echo "  → registrar1 already registered"


echo ""
echo \"Registering Department Org application users\"

export FABRIC_CA_CLIENT_HOME=$PWD/ca-client/department

# Ensure CA admin is enrolled
if [ ! -d "$FABRIC_CA_CLIENT_HOME/msp" ]; then
  echo "Enrolling Department CA admin..."
  fabric-ca-client enroll -u http://admin:adminpw@localhost:${DEPARTMENT_CA_PORT} --caname ca-department
fi

# CS Department Staff
fabric-ca-client register --caname ca-department \
  --id.name cs-staff1 --id.secret cs-staff1pw --id.type client \
  --id.attrs "role=staff:ecert,department=CS:ecert" \
  2>/dev/null && echo "  ✓ cs-staff1 registered" || echo "  → cs-staff1 already registered"

# EE Department Staff
fabric-ca-client register --caname ca-department \
  --id.name ee-staff1 --id.secret ee-staff1pw --id.type client \
  --id.attrs "role=staff:ecert,department=EE:ecert" \
  2>/dev/null && echo "  ✓ ee-staff1 registered" || echo "  → ee-staff1 already registered"

# Finance Staff
fabric-ca-client register --caname ca-department \
  --id.name finance1 --id.secret finance1pw --id.type client \
  --id.attrs "role=staff:ecert,department=finance:ecert" \
  2>/dev/null && echo "  ✓ finance1 registered" || echo "  → finance1 already registered"

# Library Staff
fabric-ca-client register --caname ca-department \
  --id.name library1 --id.secret library1pw --id.type client \
  --id.attrs "role=staff:ecert,department=library:ecert" \
  2>/dev/null && echo "  ✓ library1 registered" || echo "  → library1 already registered"

echo ""
echo \"\"
echo "  All application users registered!"
echo ""
echo "  University Org (ca-university:${UNIVERSITY_CA_PORT}):"
echo "    admin1     (role=admin)"
echo "    registrar1 (role=registrar)"
echo ""
echo "  Department Org (ca-department:${DEPARTMENT_CA_PORT}):"
echo "    cs-staff1  (role=staff, dept=CS)"
echo "    ee-staff1  (role=staff, dept=EE)"
echo "    finance1   (role=staff, dept=finance)"
echo "    library1   (role=staff, dept=library)"
echo \"\"
