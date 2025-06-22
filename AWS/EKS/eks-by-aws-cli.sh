#!/bin/bash

set -e
REGION="ap-northeast-2"
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDR="10.0.1.0/24"
PRIVATE_SUBNET_CIDR="10.0.2.0/24"

# 1. VPC 생성
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --output text \
  --query 'Vpc.VpcId')

echo "[+] VPC created: $VPC_ID"

aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# 2. 인터넷 게이트웨이 생성 및 연결
IGW_ID=$(aws ec2 create-internet-gateway --region $REGION \
  --output text --query 'InternetGateway.InternetGatewayId')

echo "[+] IGW created: $IGW_ID"
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

# 3. 서브넷 생성
PUB_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_CIDR \
  --availability-zone ${REGION}a \
  --output text --query 'Subnet.SubnetId')

PRI_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR \
  --availability-zone ${REGION}a \
  --output text --query 'Subnet.SubnetId')

echo "[+] Public Subnet: $PUB_SUBNET_ID"
echo "[+] Private Subnet: $PRI_SUBNET_ID"

# 4. 라우트 테이블 생성 및 연결 (퍼블릭용)
PUB_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID --output text --query 'RouteTable.RouteTableId')

echo "[+] Public Route Table: $PUB_RT_ID"

aws ec2 create-route \
  --route-table-id $PUB_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws ec2 associate-route-table --subnet-id $PUB_SUBNET_ID --route-table-id $PUB_RT_ID

# 5. NAT 게이트웨이 생성을 위한 탄력 IP
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --output text --query 'AllocationId')
NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUB_SUBNET_ID \
  --allocation-id $EIP_ALLOC_ID \
  --output text --query 'NatGateway.NatGatewayId')

echo "[+] NAT Gateway: $NAT_GW_ID"
echo "[!] NAT Gateway 생성 완료까지 약 1~2분 대기 중..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID

# 6. 프라이빗 라우트 테이블 생성
PRI_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID --output text --query 'RouteTable.RouteTableId')

echo "[+] Private Route Table: $PRI_RT_ID"

aws ec2 create-route \
  --route-table-id $PRI_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GW_ID

aws ec2 associate-route-table --subnet-id $PRI_SUBNET_ID --route-table-id $PRI_RT_ID

# 7. EKS 클러스터 생성 (eksctl 없이)
ROLE_NAME="EKSClusterRole"
ROLE_ARN=$(aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://<(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "eks.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
) \
  --output text --query 'Role.Arn')

aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

aws eks create-cluster \
  --name my-eks-cluster \
  --region $REGION \
  --role-arn $ROLE_ARN \
  --resources-vpc-config subnetIds=$PUB_SUBNET_ID,$PRI_SUBNET_ID,endpointPublicAccess=true

echo "[✓] EKS Cluster provisioning started"

# 8. Node Group IAM Role 생성 및 노드 그룹 추가
NODE_ROLE_NAME="EKSNodeRole"
NODE_ROLE_ARN=$(aws iam create-role \
  --role-name $NODE_ROLE_NAME \
  --assume-role-policy-document file://<(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
) \
  --output text --query 'Role.Arn')

aws iam attach-role-policy --role-name $NODE_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name $NODE_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam attach-role-policy --role-name $NODE_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

# wait for cluster to be active
aws eks wait cluster-active --name my-eks-cluster --region $REGION

echo "[+] Creating managed node group..."
aws eks create-nodegroup \
  --cluster-name my-eks-cluster \
  --region $REGION \
  --nodegroup-name my-node-group \
  --subnets $PUB_SUBNET_ID $PRI_SUBNET_ID \
  --node-role $NODE_ROLE_ARN \
  --scaling-config minSize=1,maxSize=2,desiredSize=1 \
  --disk-size 20 \
  --instance-types t3.medium \
  --ami-type AL2_x86_64

# wait for node group to be active
aws eks wait nodegroup-active --cluster-name my-eks-cluster --nodegroup-name my-node-group --region $REGION

# 9. 테스트용 nginx Pod 배포
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-test
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
EOF

echo "--- 요약 ---"
echo "VPC ID: $VPC_ID"
echo "Public Subnet: $PUB_SUBNET_ID"
echo "Private Subnet: $PRI_SUBNET_ID"
echo "EKS Cluster: my-eks-cluster"
echo "Node Group: my-node-group"
echo "EIP/NAT: $NAT_GW_ID ($EIP_ALLOC_ID)"
echo "Role ARN: $ROLE_ARN"
echo "Node Role ARN: $NODE_ROLE_ARN"
