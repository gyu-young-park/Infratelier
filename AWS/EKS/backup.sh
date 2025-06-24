#!/bin/bash

# 백업 파일 이름
BACKUP_FILE="aws_resources_backup.txt"

# 변수 값 출력 및 파일 저장
echo "Saving resource info to $BACKUP_FILE..."

cat <<EOF > $BACKUP_FILE
VPC ID: $VPC_ID
Public Subnet: $PUB_SUBNET_ID
Private Subnet: $PRI_SUBNET_ID
EKS Cluster: my-eks-cluster
Node Group: my-node-group
EIP/NAT: $NAT_GW_ID ($EIP_ALLOC_ID)
Role ARN: $ROLE_ARN
Node Role ARN: $NODE_ROLE_ARN
EOF

echo "✅ Resource information saved to $BACKUP_FILE"
