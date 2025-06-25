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

echo "[+] Public Subnet: $PUB_SUBNET_ID"

PRI_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR \
  --availability-zone ${REGION}a \
  --output text --query 'Subnet.SubnetId')

echo "[+] Private Subnet: $PRI_SUBNET_ID"

PRIVATE_SUBNET_CIDR_2="10.0.3.0/24"

PRI_SUBNET_ID_2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR_2 \
  --availability-zone ${REGION}c \
  --output text --query 'Subnet.SubnetId')

echo "[+] Second Private Subnet: $PRI_SUBNET_ID_2"

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
aws ec2 associate-route-table \
  --subnet-id $PRI_SUBNET_ID_2 \
  --route-table-id $PRI_RT_ID

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
  --resources-vpc-config subnetIds=$PRI_SUBNET_ID,$PRI_SUBNET_ID_2,endpointPublicAccess=true

echo "[✓] EKS Cluster provisioning started"
aws eks wait cluster-active --name my-eks-cluster --region $REGION

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

echo "[+] Creating managed node group..."
aws eks create-nodegroup \
  --cluster-name my-eks-cluster \
  --region $REGION \
  --nodegroup-name my-node-group \
  --subnets $PRI_SUBNET_ID $PRI_SUBNET_ID2 \
  --node-role $NODE_ROLE_ARN \
  --scaling-config minSize=1,maxSize=3,desiredSize=1 \
  --disk-size 20 \
  --instance-types t3.medium \

# wait for node group to be active
aws eks wait nodegroup-active --cluster-name my-eks-cluster --nodegroup-name my-node-group --region $REGION

# 9. bastion
BASTION_ROLE_NAME="BastionAccessRole"
BASTION_ROLE_ARN=$(aws iam create-role \
  --role-name $BASTION_ROLE_NAME \
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

echo "[+] Bastion IAM Role: $BASTION_ROLE_ARN"

aws iam attach-role-policy \
  --role-name $BASTION_ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

aws iam create-instance-profile --instance-profile-name BastionInstanceProfile

aws iam add-role-to-instance-profile \
  --instance-profile-name BastionInstanceProfile \
  --role-name $BASTION_ROLE_NAME

BASTION_SG_ID=$(aws ec2 create-security-group \
  --group-name bastion-sg \
  --description "Allow SSH and access to EKS VPC" \
  --vpc-id $VPC_ID \
  --region ap-northeast-2 \
  --output text --query 'GroupId')

# SSH 허용 (본인 IP로 제한)
MY_IP=$(curl -s http://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-id $BASTION_SG_ID \
  --protocol tcp --port 22 --cidr ${MY_IP}/32 \
  --region ap-northeast-2

# EKS 내부 통신 허용 (VPC 내부로)
aws ec2 authorize-security-group-ingress \
  --group-id $BASTION_SG_ID \
  --protocol tcp --port 443 --cidr 10.0.0.0/16 \
  --region ap-northeast-2

echo "[+] Bastion SG created: $BASTION_SG_ID"

aws ec2 create-key-pair \
  --key-name bastion-key \
  --query 'KeyMaterial' \
  --region ap-northeast-2 \
  --output text > bastion-key.pem

chmod 400 bastion-key.pem

BASTION_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-0308297ba71025b4d \
  --instance-type t3.micro \
  --key-name bastion-key \
  --security-group-ids $BASTION_SG_ID \
  --subnet-id $PUB_SUBNET_ID \
  --associate-public-ip-address \
  --iam-instance-profile Name=BastionInstanceProfile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=bastion}]' \
  --region ap-northeast-2 \
  --query 'Instances[0].InstanceId' --output text)

echo "[+] Bastion EC2 ID: $BASTION_INSTANCE_ID"

# 퍼블릭 IP 얻기
BASTION_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $BASTION_INSTANCE_ID \
  --region ap-northeast-2 \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "[+] SSH to: ssh -i bastion-key.pem ec2-user@$BASTION_PUBLIC_IP"

ssh -i bastion-key.pem ec2-user@${BASTION_PUBLIC_IP}

# AWS CLI v2
sudo yum install unzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

curl -LO "https://dl.k8s.io/release/v1.33.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# 확인
kubectl version --client

# 10. 테스트용 nginx Pod 배포
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


aws eks delete-nodegroup \
  --cluster-name my-eks-cluster \
  --nodegroup-name my-node-group \
  --region ap-northeast-2

# Node Group 삭제 완료까지 대기
aws eks wait nodegroup-deleted \
  --cluster-name my-eks-cluster \
  --nodegroup-name my-node-group \
  --region ap-northeast-2


aws eks delete-cluster \
--name my-eks-cluster \
--region ap-northeast-2

# 클러스터 삭제 완료까지 대기
aws eks wait cluster-deleted \
  --name my-eks-cluster \
  --region ap-northeast-2