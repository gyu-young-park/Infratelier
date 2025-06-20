# 1. IAM 생성 후 AWS CLI 사용 방법
Root 계정으로 AWS에 접속한 다음, 각 사용 용도에 따른 IAM 계정을 만들어 사용하는 것이 좋다.

1. IAM 접속
2. 사용자 생성
3. 사용자 이름 설정
4. 계정 생성

AWS CLI나 boto3, terraform 등에 활용하기 위해서 access key를 만들도록 하자.

1. 생성한 계정 console로 이동
2. 보안 자격 증명 탬
3. Access Key 탭에서 만들기
4. 액세스 키 모범 사례 및 대안에 CLI 선택 (사실 어떤 것이든 상관없다)
5. 결과로 나온 key를 CSV로 저장하고 보관

다음으로 해당 IAM 계정에 권한을 부여하도록 하자. IAM 계정에 권한이 있어야 원하는 동작에 대한 권한을 허락 받을 수 있다. ex, EC2 instance 생성

테스트 및 연구 용이기 때문에 `AdministratorAccess`으로 하자.

1. 권한 추가
2. 직접 정책 연결
3. AdministratorAccess 검색
4. 다음

이제 AWS CLI를 설치해보도록 하자.
https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

- mac 버전
```sh
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

설치 완료 후

```sh
aws --version
```
`aws-cli/2.25.11 Python/3.11.6 Darwin/23.3.0` 이렇게 나오면 성공이다.

# 2. AWS CLI용 EC2 Instance 생성 후, Role을 통해 AWS CLI 사용
IAM 계정 생성 후 권한을 부여하여 사용하는 방식보다는 EC2 인스턴스에 IAM Role을 부여하여, 해당 EC2 Instance에서 aws cli를 사용하는 방법이 더 좋다.

먼저 console에 가서 EC2 cli용 role을 만들어주도록 하자.
1. IAM 접속
2. 왼쪽에 '역할' 선택
3. 역할 생성 클릭
4. 신뢰할 수 있는 엔티티 유형: 'AWS 서비스'
5. 사용 사례: EC2
6. 권한 정책: AdministratorAccess (테스트와 실험을 위해서이지 실제 현업에서는 절대 X)
7. 역할 이름: AWSCliEC2Role
8. 역할 생성

다음으로 AWS CLI용 EC2에 접근하기 위한 SSH 키페어를 만들도록 하자.
1. EC2 패이지
2. 왼쪽 메뉴 바에서 '키 페어'
3. 키페어 생성
4. 이름: 'aws-cli-ec2-key'
5. 키 생성
6. chmod 400 ./aws-cli-ec2-key.pem

EC2에 적용할 보안 그룹을 생성하여 SSH만 허용하도록 만들자.
1. EC2 페이지
2. 왼쪽 메뉴 바에서 '보안 그룹'
3. 보안 그룹 생성
4. 보안 그룹 이름 'aws-cli-ec2-sg'
5. VPC는 기본값으로 설정
6. 인바운드 규칙
    1. 유형: SSH
    2. 포트: 22
    3. Source: 내 IP
7. 아웃 바운드: 기본값 유지

이제 EC2 인스턴스를 생성해보도록 하자.
1. EC2 페이지
2. 인스턴스 시작 클릭
3. 이름 'aws-cli-ec2-bastion'
4. Amazon Linux 선택
5. 인스턴스 유형: t3.mirco
6. 키페어: 'aws-cli-ec2-key'
7. 네트워크: 기본 VPC
8. 서브넷: 퍼블릭 서브넷 중 아무거나 선택
9. 퍼블릭 IP: 자동 할당
10. IAM 역할: 'AWSCliEC2Role'
11. 보안 그룹: 'aws-cli-ec2-sg'

이제 EC2 인스턴스가 프로비저닝 되었다면 다음의 명령어로 접속하도록 하자.

```sh
AWS_CLI_EC2_PUBLIC_IP=""
ssh -i "aws-cli-ec2-key.pem" ec2-user@$AWS_CLI_EC2_PUBLIC_IP

aws --version
```

다음으로 EC2 instance에 역할이 잘 붙었는지 확인해보도록 하자.
```sh
aws sts get-caller-identity
```