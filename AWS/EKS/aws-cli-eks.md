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

# 2. EKS 생성 