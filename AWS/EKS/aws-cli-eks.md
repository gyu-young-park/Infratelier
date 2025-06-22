EKS cluster를 AWS CLI로만 설치해보도록 하여, EKS 설치에 필요한 AWS 자원들이 무엇이 있는 지 알아보도록 하자. 

# 1. VPC 생성
bastion용 EC2 instance와 EKS Cluster가 사용할 VPC 네트워크를 먼저 만들어 주도록 하자.

```sh
REGION="ap-northeast-2"
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDR="10.0.1.0/24"
PRIVATE_SUBNET_CIDR="10.0.2.0/24"

VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --output text \
  --query 'Vpc.VpcId')
```
`REGION`에 `VPC_CIDR`를 가진 eks용 VPC를 만들겠다는 것이다. `VPC_ID`에 생성된 vpc의 id값이 할당될 것이다.

