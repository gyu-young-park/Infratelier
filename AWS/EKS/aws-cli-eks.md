EKS cluster를 AWS CLI로만 설치해보도록 하여, EKS 설치에 필요한 AWS 자원들이 무엇이 있는 지 알아보도록 하자. 

# 1. VPC 생성
bastion용 EC2 instance와 EKS Cluster가 사용할 VPC 네트워크를 먼저 만들어 주도록 하자.

```sh
REGION="ap-northeast-2"
VPC_CIDR="10.0.0.0/16"

VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --output text \
  --query 'Vpc.VpcId')
```
`REGION`에 `VPC_CIDR`를 가진 eks용 VPC를 만들겠다는 것이다. `VPC_ID`에 생성된 vpc의 id값이 할당될 것이다.

다음으로 `VPC_ID`를 통해서 해당 VPC에 **DNS 호스트 이름**을 활성화하도록 하자. 이 기능을 활성화하면 해당 VPC에 배포되는 EC2 인스턴스는 `ec2-203-0-113-25.compute-1.amazonaws.com`와 같은 DNS 이름을 부여 받을 수 있다.

```sh
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
```

> EC2 instance 특성상, 재기동 시에 공인 IP가 바뀌기 때문에 DNS 이름도 바뀐다. 따라서, DNS를 고정하고 싶다면 elastic IP를 배정하거나, Route 53으로 이름을 부야하도록 하자.

## Subnet 생성
이제 VPC 안에 subnet을 만들도록 하자. subnet은 외부에 접근이 가능한 bastion host를 위해 public subnet을 하나 만들고 eks node들이 배포될 폐쇄망 형인 private subnet으로 두 개를 만들 것이다.

먼저 public subnet을 만들도록 하자. 기본적으로 subnet을 만들기 위해서는 다음의 파라미터가 필요하다.
1. Subnet을 배포할 VPC 
2. 가용 영역(AZ)
3. CIDR

```sh
PUBLIC_SUBNET_CIDR="10.0.1.0/24"

PUB_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_CIDR \
  --availability-zone ${REGION}a \
  --output text --query 'Subnet.SubnetId')

echo "[+] Public Subnet: $PUB_SUBNET_ID"
```
`PUB_SUBNET_ID`가 배정되었다면 생성에 성공한 것이다. 가용 영역을 설정하는 `--availability-zone`을 `${REGION}a` 이렇게 설정해서 `ap-northeast-2a`에 설정하도록 하는 것이다.

public subnet을 만들었지만, public subnet이 외부 네트워크인 인터넷과 연결된 것은 아니다. 외부 네트워크에 연결해주기 위해서는 public subnet의 traffic이 외부로 전달될 수 있도록 하는 라우터가 필요하다. 그것이 바로 AWS의 **IGW**이다. 

IGW는 AWS VPC에서 외부 인터넷과 통신하기 위한 관문 역할을 하는 리소스이다. VPC가 외부 네트워크와 연결하기 위해서 IGW라는 것을 하나 두는 것이다. 따라서, 생성 시에 public subnet에 바로 연결하는 것이 아니라, VPC에 연결하도록 해야한다. 

IGW 생성 시 필요한 것들은 다음과 같다.
1. REGION
```sh
IGW_ID=$(aws ec2 create-internet-gateway --region $REGION \
  --output text --query 'InternetGateway.InternetGatewayId')

echo "[+] IGW created: $IGW_ID"
```

어떤 REGION에 IGW를 생성할 지 결정해야하고, 생성되었다면 IGW를 VPC에 연결하도록 한다. 
1. VPC_ID
2. IGW_ID

```sh
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID

aws ec2 describe-internet-gateways   --internet-gateway-id $IGW_ID --query "InternetGateways[0].Attachments[0].VpcId"
```
잘 연결되었다면 해당 IGW에 연결된 `VPC_ID`가 결과로 나올 것이다.

이제 우리의 VPC에도 외부 네트워크와 연결될 라우터인 IGW를 만들었다. 이제 public subnet이 IGW로 접근해 외부 인터넷에 접속할 수 있도록, 라우팅 테이블을 만들어주도록 하자.

> 일반적으로 외부 네트워크(인터넷)은 `0.0.0.0`으로 설정해서 'internet gateway를 타도록 설정한다'라고 한다. 기존의 on-premise 서버에서 `ip route show` 명령어로 자신의 서버의 routing table을 확인하면 `0.0.0.0`은 외부로 통하는 router의 IP로 물려있는 것을 볼 수 있을 것이다. 이에 따라 AWS도 같은 로직으로 `0.0.0.0`에 IGW의 IP를 설정하도록 하는 것이다.

라우팅 테이블 리소스도 IGW와 마찬가지로 VPC 단위이다.
1. VPC_ID

```sh
PUB_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID --output text --query 'RouteTable.RouteTableId')

echo "[+] Public Route Table: $PUB_RT_ID"
```
라우팅 테이블은 만들었지만 해당 라우팅 테이블에 라우팅 정보가 없다. 라우팅 정보로 '`0.0.0.0`으로 향하는 packet은 `IGW`로 보낸다' 라는 정보를 넣어주도록 하자. `0.0.0.0`은 모든 IP 주소를 말한다. 라우팅 정보를 만들기 위해서는 다음이 필요하다.
1. routing table
2. gateway-id
3. 라우팅 CIDR

즉, 라우팅 CIDR에 해당하는 packet은 `gateway-id`로 보내라는 것이다. 우리의 예로 보면 `0.0.0.0/0`은 `IGW_ID`로 가라는 것이다.
```sh
aws ec2 create-route \
  --route-table-id $PUB_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID
```
반환 값으로 `true`가 나왔다면 성공이다. 이제 라우팅 테이블에 라우팅 정보도 만들었으니, 라우팅 테이블을 subnet에 연결시키도록 하자.

```sh
aws ec2 associate-route-table --subnet-id $PUB_SUBNET_ID --route-table-id $PUB_RT_ID
```
`associated`가 나왔다면 성공이다. 

다음으로 private subnet을 만들어보도록 하자.

```sh
PRIVATE_SUBNET_CIDR="10.0.2.0/24"

PRI_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR \
  --availability-zone ${REGION}a \
  --output text --query 'Subnet.SubnetId')

echo "[+] Private Subnet: $PRI_SUBNET_ID"
```
가용 영역으로 `ap-northeast-2a`을 설정해준 것이다.

`PRI_SUBNET_ID`값이 잘 나왔다면 성공이다.

> 지금은 두 서브넷을 같은 가용 영역에 배포했지만 서로 다른 가용 영역에 배포하는 것이 고가용성을 보장하므로 더 좋은 방식이다.

Private subnet은 기본적으로 폐쇄망으로 외부에서 접근은 public subnet인 bastion host로만 가능하도록 한다. 그런데, private subnet에 배포될 eks node들은 외부 네트워크와 연결이 필요할 때가 있다. 즉, eks node들이 외부에 요청을 보내고 받는 것은 허용하고, 외부에서 eks node에 직접 접근은 막는 것이다.

이를 위해서 NAT gateway를 사용할 것이다. IGW를 사용하게 되면 외부와 직접적인 연결이 가능히지만 이는 외부에서도 우리의 private network에 접근이 가능하다는 것을 의미한다. NAT의 경우는 공인 IP로 private network에 있는 host의 IP를 NAT(변환)시켜서 외부에 데이터를 요청하지만, 반대로 NAT gateway가 갖고 있는 IP로 외부에서 요청을 한다고 해서 우리의 private network에 연결하도록 하진 않는다. 즉, 외부에서 private network에 요청을 보내는 인바운드 트래픽은 막고, 반대로 private network에서 외부로 요청을 보내는 아웃바운드 트래픽은 NAT를 통해 허용한다. 

더불어 NAT gateway는 public subnet과 연결되어야 하는데, NAT gateway는 말 그대로 기능이 NAT를 해주는 것이지, 외부 연결까지 담당하진 않는다. 외부 연결을 담당하는 것은 IGW이기 떼문에 IGW에 라우팅 테이블로 연결된 public subnet과 연결되어야 하는 것이다.

> 실제로 On-premise에서도 외부 연결이 가능한 다른 host에 iptables로 private network에 있는 host의 ip를 NAT 시켜서 외부 네트워크에 연결이 가능하도록 한다. 물론, 반대의 접근은 막는다.

먼저 NAT gateway가 외부 네트워크에서 사용할 공인 IP가 필요하다. AWS에서는 이를 elastic IP라고 한다.
```sh
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --output text --query 'AllocationId')
```

NAT gateway를 생성하도록 하자. NAT gateway를 생성하기 위해서는 다음이 기본적으로 필요하다.
1. 연결할 public subnet
2. elastic IP (고정 공연 IP)
```sh
NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUB_SUBNET_ID \
  --allocation-id $EIP_ALLOC_ID \
  --output text --query 'NatGateway.NatGatewayId')

echo "[+] NAT Gateway: $NAT_GW_ID"
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID
```
NAT 생성에 성공해도 제대로 동작하게 하기 위해서는 1~2분 동안 기다려야 한다. 실제로 AWS console에 가서 보면 상태가 `Pending`으로 되어있을 것이다. 그래서 `aws ec2 wait`으로 우리의 NAT gateway가 생성될 때까지 기다리는 것이다.

shell에서 hang이 풀렸다면 console로 가서 `Available`이 된 것을 볼 수 있을 것이다.

이제 NAT gateway를 private subnet에 연결하도록 하자. 이를 위해서 private subnet의 기본 라우팅인 `0.0.0.0/0`가 NAT gateway로 통하도록 만드는 것이다.

위의 public subnet에서 라우팅 테이블을 만들어 IGW에 연결한 것과 같은 방식이다.
```sh
PRI_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID --output text --query 'RouteTable.RouteTableId')

echo "[+] Private Route Table: $PRI_RT_ID"

aws ec2 create-route \
  --route-table-id $PRI_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GW_ID

aws ec2 associate-route-table --subnet-id $PRI_SUBNET_ID --route-table-id $PRI_RT_ID
```
`associated`가 나왔다면 성공이다.

다음으로 두 번째 private subnet을 만들어주되, AZ(가용 영역)을 앞에서 만든 것과 다르게 만들도록 하자. 이렇게 두 개의 private subnet을 만들고 가용 영역을 서로 다르게 만드는 이유는 EKS에서 사용 할 control plane, worker node에 고가용성을 보장하기 위함이다. 

1. public subnet의 경우 ENI에 공인 IP가 붙으므로 AWS CNI 사용 시에 pod에 공인 IP가 붙을 수도 있다. 이는 보안상에 좋지 못하고, IP 자원 낭비가 극심하다.
2. private subnet을 사용하되 고가용성을 위해서 두 private subnet은 서로 다른 AZ로 배포되어야 한다.

> IP가 뭐 그리 비싼 자원이냐고 생각할 수 있지만, IP는 실제로 매우 비싼 리소스 중 하나이다. on-premise 환경에서는 IP를 아끼기 위해서 NAT, CIDR 등등 각종 네트워크 기술과 가상화 및 오프로딩 방식들을 사용하여 IP를 아끼곤 한다. 

```sh
PRIVATE_SUBNET_CIDR_2="10.0.3.0/24"

PRI_SUBNET_ID_2=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_CIDR_2 \
  --availability-zone ${REGION}c \
  --output text --query 'Subnet.SubnetId')

echo "[+] Second Private Subnet: $PRI_SUBNET_ID_2"
```
앞에서 먼저 만들었던 첫번째 private subnet은 가용 영역이 `ap-northeast-2a`이므로, 두번째 private subnet의 가용 영역은 `ap-northeast-2c`로 설정하게 두었다. 

다음으로 `PRI_SUBNET_ID_2`에도 route table을 설정해주어 public subnet의 NAT Gateway를 타고 트래픽이 외부로 나갈 수 있도록 설정해주도록 하자.
```sh
aws ec2 associate-route-table \
  --subnet-id $PRI_SUBNET_ID_2 \
  --route-table-id $PRI_RT_ID
```
`associated`가 나왔다면 성공이다.

# 2. EKS 생성
EKS cluster는 AWS에서 엄밀히 말하면 kubernetes의 control plane만 말하는 것이다. 따라서 EKS cluster를 만드는 것은 control plane을 만드는 것이지 worker node를 만드는 것은 아니다. 

EKS 클러스터를 프로비저닝할 때는 클러스터 제어 플레인(Control Plane) 이 사용할 IAM 역할에 최소한 AmazonEKSClusterPolicy 정책을 포함시켜야 한다. EKS control plane에서는 자동으로 다음과 같은 자원을 제어하기 때문이다. 

1. ENI 생성/삭제 (EC2 네트워크 인터페이스)
2. 로드밸런서 연동 (Service Type: LoadBalancer)
3. CloudWatch 로그 전송
4. 보안 그룹 조회

이 역할이 없다면 제대로 생성되지 않거나, 우리가 원하는 대로 동작하지 않을 수 있다. 

먼저 IAM Role을 만든다음, Role에 `AmazonEKSClusterPolicy` Policy를 연결해준다음, 해당 Role을 eks control plane에 연결하도록 하는 것이다.  
1. `AmazonEKSClusterPolicy`: control plane가 AWS 리소스를 다룰 수 있게하는 정책이다.  보안 그룹, 서브넷 조회, ENI 생성 등의 기능을 할 수 있도록 권한을 주는 것이다. 

```sh
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
```

이제 EKS Cluster를 만들어보도록 하자. EKS Cluster를 만들기 위해서는 기본적으로 다음이 필요하다.
1. Region
2. Role arn (control plane에서 AWS 자원을 제어하기 위해서 필요하다)
3. Private Subnet1, Private Subnet2 
```sh
aws eks create-cluster \
  --name my-eks-cluster \
  --region $REGION \
  --role-arn $ROLE_ARN \
  --resources-vpc-config subnetIds=$PRI_SUBNET_ID,$PRI_SUBNET_ID_2,endpointPublicAccess=true

aws eks wait cluster-active --name my-eks-cluster --region $REGION
```
`my-eks-cluster`가 생성될 때까지 기다리게 된다. AWS console로 가서 EKS 클러스터에 가보면 생성 중이라고 나올 것이다. 

`aws eks create-cluster`로 만든 eks cluster는 kubernetes에서 control plane에 속한다. 즉, etcd, api-server, controller, scheduler를 관리하는 control plane node만 만든 것이고, pod들이 실제로 배포될 worker node를 만든 것이 아니다.

왜 EKS는 worker node를 위한 node group을 따로 만드냐면, node의 역할을 하는 것이 EC2 인스턴스들이기 때문이다. node 역할을 하는 EC2 instance의 type(`t3.medium`, `g4dn.xlarge`), OS 등을 달리 만들어 배포할 수도 있고, 용도에 따라 다르게 배포시킬 수도 있기 때문이다. 가령 GPU 용 node를 따로 관리하도록 하는 것이다. 이렇게 node group을 따로 두어 eks 프로비저닝을 할 때 사용자가 원하는 node들을 선택해서 만들어 kubernetes에 사용할 수 있는 것이다.

> EKS를 배포하는 방법 중에 nodegroup을 통해서 worker node를 만드는 방법을 '관리형 방식'이라고 한다. '관리형 방식'은 반복되는 기능들을 AWS에서 자동으로 해주는 기능이지만 node에 직접 사용자가 접근하지 못하게 한다. 이러한 방식은 사실 실제 배포 상에서 디버깅의 어려움이 있기 때문에 별로 좋은 방법이 아니다. 실제 배포에서는 관리형 방식이 아니라 EC2 instance를 직접 올리고 연결하는 방식을 사용한다. 여기서는 먼저 관리형 방식인 managed node로 배포해보도록 하자. 

pod를 배포할 때는 node selector, affinity를 사용해서 특정 node에 배포할 수 있도록 하는 것이다.

EKS에서 pod가 배포되는 worker node는 node group으로 실제로는 EC2 instance에 불과하다. EC2 instance이기 때문에 AWS 리소스들을 제어하고 사용하기 위해서 ARN을 설정해주어야 한다. node group에 사용되는 ARN에 필요한 필수 policy들은 다음과 같다.

1. `AmazonEKSWorkerNodePolicy`: worker node가 cluster의 control plane와 통신하기 위해서 필요하다. cluster 정보를 조회해서 자신(node)를 등록시키기 위해 필요한 것이다.
2. `AmazonEKS_CNI_Policy`: VPC CNI plugin을 통해 pod를 생성할 시에 pod에 ENI가 붙게된다. 즉, pod가 배포된 node에 pod에 대한 ENI가 직접 붙게되는 것이다. 이를 위해서 EC2 network에 대한 권한들이 필요한 것이다.
3. `AmazonEC2ContainerRegistryReadOnly`: EC2 instance가 ECR에서 컨테이너 이미지를 pull할 수 있게 해준다. 

이제 node group을 위한 ARN을 만들고, 위의 3개의 policy를 연결시키도록 하자.
```sh
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
```

다음으로 AWS node group을 만들고 eks cluster(control plane)를 연결시키도록 하자. nodegroup 생성에 필요한 정보들은 다음과 같다.
1. EKS cluster(control plane) 이름(`my-eks-cluster`)
2. Nodegroup 이름
3. Private subnet 2개 이상
4. Node ARN
5. scaling config: 최대, 최소, node 유지 수
6. disk size
7. EC2 instance type

추가로 어떤 OS를 사용할 지 `--ami-type`도 설정할 수 있지만, 아무것도 넣지 않으면 자동으로 설정된다. 참고로 kuberntes 1.33 기준으로 `AL2_x86_64`은 이제 deprecated되어 못 사용한다. 
```sh
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
```
잠시만 기다리면 nodegroup이 배포되고 AWS console에서 확인할 수 있다.

EKS cluster, nodegroup 배포에 성공했다면, 이제 배포한 host에서 `kubectl`로 접근해보도록 하자.
```sh
# kubectl for EKS 1.33
curl -LO "https://dl.k8s.io/release/v1.33.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# 확인
kubectl version --client
```

`kubectl`이 설치되었다면 `kubectl`을 위한 kubeconfig를 설정해주어야 한다. `aws` cli를 사용해서 쉽게 설정이 가능하다. 단, 이 명령어는 반드시 eks cluster를 배포한 host에서만 성공한다.
```sh
aws eks update-kubeconfig --name my-eks-cluster --region ap-northeast-2
```

이제 kubernetes cluster에 잘 접근되는 지 확인해보자. 
```sh
kubectl get po -A
NAMESPACE     NAME                      READY   STATUS    RESTARTS   AGE
kube-system   aws-node-njrtz            2/2     Running   0          18m
kube-system   coredns-c844dd74d-kllg5   1/1     Running   0          21m
kube-system   coredns-c844dd74d-w268t   1/1     Running   0          21m
kube-system   kube-proxy-dhgtc          1/1     Running   0          18m
```
위와 같이 pod들이 나왔다면 성공이다.

# 3. Bastion EC2 instance 생성
private subnet에 있는 EKS 용 instance에 직접 들어가서 `kubectl`을 사용하기 보다는 접근용 bastion host를 만드는 것이 일반적인 방법이다. 이는 보안적인 측면에서 장점이 있고 node에 대한 제한된 접근을 통해 최소 권한으로만 부여하여 시스템을 동작할 수 있다는 장점이 있다.

bastion host를 통해서 기본적인 `kubectl` 명령들을 실행할 수 있도록 하면 된다.

bastion host도 EC2 instance이기 때문에 EKS 정보를 읽기 위해서는 role을 부여해야한다.

이미 만들어진 policy 중에서는 딱히 적절한 것이 없으므로 하나 만들어주어야 한다. `eks:DescribeCluster` 동작에 대해서 허용하는 policy를 만들고 role에 부여하도록 하자.

아래에 policy 생성 시 policy의 ARN을 위한 resource 칸에 `계정_번호`가 있으니 개인의 계정 번호를 넣어주도록 하자.
```sh
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

cat > eks-describe-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster"
      ],
      "Resource": "arn:aws:eks:ap-northeast-2:{계정_번호}:cluster/my-eks-cluster"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name $BASTION_ROLE_NAME \
  --policy-name EksDescribeClusterPolicy \
  --policy-document file://eks-describe-policy.json
```

EC2 instance에 role을 부여하기 위해서는 role을 부여한 profile을 생성한 후 profile을 EC2 instance에 할당해야한다. 참고로 EC2는 직접 Role을 부여받을 수 없고 profile을 통해서 간접적으로 role을 부여받아야 한다.
```sh
# 인스턴스 프로파일 생성 후 Role 연결
aws iam create-instance-profile --instance-profile-name BastionInstanceProfile

aws iam add-role-to-instance-profile \
  --instance-profile-name BastionInstanceProfile \
  --role-name $BASTION_ROLE_NAME
```

이제 bastion을 위한 security group을 만들도록 하자. 내 IP 이외의  security group을 만들기 위해 필요한 것은 다음과 같다.
1. vpc
2. region

```sh
BASTION_SG_ID=$(aws ec2 create-security-group \
  --group-name bastion-sg \
  --description "Allow SSH and access to EKS VPC" \
  --vpc-id $VPC_ID \
  --region ap-northeast-2 \
  --output text --query 'GroupId')
```

다음으로 생성한 security group에 ingress rule을 만들어 외부 접근을 최소한으로 하도록 하자.
1. 내 컴퓨터 IP는 허용
2. VPC 내부의 통신은 허용 (10.0.0.0/16)

```sh
# 내 IP는 허용
MY_IP=$(curl -s http://checkip.amazonaws.com)
aws ec2 authorize-security-group-ingress \
  --group-id $BASTION_SG_ID \
  --protocol tcp --port 22 --cidr ${MY_IP}/32 \
  --region ap-northeast-2

# EKS 내부 통신 허용 (VPC 내부)
aws ec2 authorize-security-group-ingress \
  --group-id $BASTION_SG_ID \
  --protocol tcp --port 443 --cidr 10.0.0.0/16 \
  --region ap-northeast-2

echo "[+] Bastion SG created: $BASTION_SG_ID"
```

다음으로 EC2 bastion에 보안 접속하기 위한 SSH key-pair를 만들도록 하자.
```sh
aws ec2 create-key-pair \
  --key-name bastion-key \
  --query 'KeyMaterial' \
  --region ap-northeast-2 \
  --output text > bastion-key.pem
```

이제 bastion host용 EC2 instance를 만들도록 하자. 필요한 매개변수는 다음과 같다.
1. image-id: ami-0c5b5fef8f4de7a4f을 써보자
2. instance type: t3.micro
3. security group
4. subnet: public subnet을 설정하도록 하자.
5. region: ap-northeast-2
6. key pair
7. instance profile: role부여를 위함 
```sh
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
```
`BASTION_INSTANCE_ID`가 출력되었다면 제대로 만들어진 것이다. 이제 bastion host에 접속하기 위해 bastion host public ip를 갸져오도록 하자.

```sh
BASTION_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $BASTION_INSTANCE_ID \
  --region ap-northeast-2 \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "[+] SSH to: ssh -i bastion-key.pem ec2-user@$BASTION_PUBLIC_IP"
```
얻어왔다면 접속해보도록 하자.

```sh
ssh -i bastion-key.pem ec2-user@${BASTION_PUBLIC_IP}
```

접속에 성공했다면 빠져 나오도록 하자.

# 4. Bastion과 EKS cluster 연결
bastion host를 만들었으니, 이제 EKS cluster와 bastion host를 연결해보도록 하자. 

먼저 bastion host에 접속하여 `kubectl`을 설정하기 전에 kubernetes cluster에 `aws-auth` configmap을 설정해야한다. 이는 kuberntes cluster의 RBAC 시스템에 따라 권한을 부여하는 과정으로 AWS role을 설정한 bastion host라도 해당 EKS cluster에 등록되지 않으면 `kubectl`로 접근이 안된다.

따라서, `kubectl`을 쓸 수 있는 host에서 `aws-auth` configmap을 설정해주어야 한다. 우리의 경우 eks cluster를 프로비저닝한 host에서 하면 된다. 

우리가 만든 bastion을 `aws-auth` configmap에 설정하기 위해서는 bastion에 부여된 role arn을 설정해주면 된다. 
1. bastion host에 부여된 Role ARN
```sh
BASTION_HOST_ROLE=$(aws iam get-instance-profile   --instance-profile-name BastionInstanceProfile   --query 
'InstanceProfile.Roles[0].Arn')

echo $BASTION_HOST_ROLE
```
`"arn:aws:iam::970547376416:role/BastionAccessRole"` 이런 식으로 나오면 성공이다.

이제 해당 bastion role arn을 EKS aws-auth configmap에 설정해주면 된다.
```sh
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::970547376416:role/EKSNodeRole
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::970547376416:role/BastionAccessRole
      username: bastion-admin
      groups:
        - system:masters
```
위와 같이 aws-auth configmap을 바꿔주고 이제 bastion host로 가면 된다.

bastion host에 접근했다면 EKS cluster에 접근하여 kubernetes resource를 다룰 수 있는 기본 cli들을 설치하도록 하자.
```sh
# kubectl for EKS 1.33
curl -LO "https://dl.k8s.io/release/v1.33.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# 확인
kubectl version --client
```

이제 eks update-kubeconfig 명령어를 사용해서 bastion host의 `kubectl`에 `kubeconfig`를 설정해주도록 하자. 
```sh
aws eks update-kubeconfig --name my-eks-cluster --region ap-northeast-2
```

설정이 완료되었다면 `kubectl`이 제대로 동작하는 지 보도록 하자.
```sh
kubectl get po -A

NAMESPACE     NAME                      READY   STATUS    RESTARTS   AGE
kube-system   aws-node-njrtz            2/2     Running   0          46m
kube-system   coredns-c844dd74d-kllg5   1/1     Running   0          49m
kube-system   coredns-c844dd74d-w268t   1/1     Running   0          49m
kube-system   kube-proxy-dhgtc          1/1     Running   0          46m
```

성공적으로 bastion host에 연결된 것이다. 

이제 마지막으로 pod를 하나 배포해고 요청을 보내보도록 하자.
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25.3
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```
AWS EKS는 `LoadBalancer` 타입의 서비스를 만들면 ELB를 자동으로 생성하므로, 외부에서도 접근이 가능하다. 참고로 다음의 rule에 따라서 `LoadBalancer`의 ELB가 배정된다.
1. Loadbalancer + HTTP: ALB
2. Loadbalancer + TCP: NLB

```sh
kubectl get svc nginx-service
NAME            TYPE           CLUSTER-IP     EXTERNAL-IP                                                                    PORT(S)        AGE
nginx-service   LoadBalancer   172.20.83.79   a558ac31277e74860b135a4c2d62b3df-1198762502.ap-northeast-2.elb.amazonaws.com   80:32183/TCP   4m13s
```
생성된 `a558ac31277e74860b135a4c2d62b3df-1198762502.ap-northeast-2.elb.amazonaws.com`에 `curl`을 보내어 nginx index화면이 나오면 성공이다.

```sh
curl a558ac31277e74860b135a4c2d62b3df-1198762502.ap-northeast-2.elb.amazonaws.com
...
<h1>Welcome to nginx!</h1>
...
```
이렇게 나오면 성공이다. 

# 5. EKS cluster 내리기
다른 AWS resource들은 비용적으로 그렇게 비싸지 않지만, EKS는 조금 비싸다 한달 기준으로 72,000이 나올 수 있으므로 공부를 위해서라면 배포하고 바로바로 내리는 것이 좋다.

```sh
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
```