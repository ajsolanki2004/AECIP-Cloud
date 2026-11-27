#!/usr/bin/env bash
set -e

echo "============================================================"
echo "    TEAR DOWN AECIP AWS INFRASTRUCTURE (STOP CHARGES)       "
echo "============================================================"

read -p "Are you sure you want to destroy all AWS resources? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Tear down aborted."
    exit 0
fi

cd terraform
echo "Running terraform destroy..."
terraform destroy -auto-approve

echo ""
echo "All AWS cloud resources successfully destroyed. Charges stopped."
