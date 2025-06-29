# Boto3
EC2 aws-cli 서버에서 다음의 명령어로 python3를 설치
```sh
sudo yum update -y
sudo yum install -y python3
python3 --version

sudo yum install -y python3-pip
pip3 --version
```

다음으로 가상 환경을 만들고 `boto3` 라이브러리를 설치해보도록 하자.

```sh
mkdir boto3-practice && cd ./boto3-practice
python3 -m venv .venv
source .venv/bin/activate

pip install boto3 boto3-stubs mypy-boto3-ec2 mypy-boto3-sts mypy-boto3-iam
```
`boto3`만 설치해도 AWS CLI 기능을 python 코드를 만들 수 있지만, python의 특징 상 타입 추론 기능을 도움받기가 어렵다. 따라서, `boto3` 이외의 다른 라이브러리들은 개발에 자동완성 편의를 제공하기 위해서 추가한 것들이다.

다음으로 해당 호스트에 AWS 계정을 설정해야하는데, aws-cli에 성공한 호스트라면 `boto3`도 문제없이 연결된다. 만약 안되어 있다면 다음의 명령어로 가능하다.

```sh
aws configure
```
accesskey와 secretkey를 설정하면 `~/.aws/credentials`에 설정이 저장된다.

이제 `boto3`를 통해서 aws 명령을 실행해보도록 하자.

```py
import boto3

sts = boto3.client("sts")
res = sts.get_caller_identity()

account = res["Account"]
arn = res["Arn"]
user_id = res["UserId"]

print(f"Account: {account}, ARN: {arn}, UserId: {user_id}")

if arn.endswith("root"):
    print("root 사용 중")
else:
    print("root 아님: " + arn)
```
응답으로 현재 계정의 정보가 나온다면 성공한 것이다.
