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

# 2. Bastion EC2 Instance 생성 후, Role을 통해 AWS CLI 사용
IAM 계정 생성 후 권한을 부여하여 사용하는 방식보다는 EC2 인스턴스(Bastion host)에 IAM Role을 부여하여, 해당 EC2 Instance에서 aws cli를 사용하는 방법이 더 좋다.

