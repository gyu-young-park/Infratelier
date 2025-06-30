# Terraform
1. code를 통해 인프라 배포를 가능하게 하는 application
2. 다양한 provider를 통해 멀티 클라우드에 배포하기 쉬워짐
3. 배포되어 있는 리소스들을 코드로 관리 가능
4. 선언적인 형태로 생성/삭제/변경 등을 코드를 통한 절차적인 방식이 아닌, 명령을 통해서 제어 및 관리 가능

## terraform Provider
provider는 특정 업체(AWS, GCP, AZure 등) 또는 기능(TLS)을 사용하기 위한 플러그인을 공급해주는 역할을 한다.

아래는 `aws` 공급 업체에 대해서 region을 설정해 리소스를 설정하는 것이다.
```tf
provider "aws" {
    region = "ap-northeast-2"
}
```

## terraform의 기본 명령어
1. `terraform init`: 사용 할 프로바이더 설치 (`.terraform 폴더 생성`)
2. `terraform plan`: 실제 작업이 진행되는 것은 아니고, 배포 또는 삭제, 변경 등에 대한 작업 계획을 보여준다.
3. `terraform apply`: 실제 배포를 수행하는 명령어
4. `terraform import`: terraform으로 배포하지 않은 다른 방식으로 배포한 리소스를 terraform이 관리할 수 있또록 리소스 상태 파일에 가져오는 것이다.
5. `terraform fmt`: 코드 포매팅

## terraform 상태 파일이란
1. 배포된 상태를 기록하는 파일
2. 배포 계획, 변경된 점 등을 파익
3. import 명령을 통해 배포된 리소스를 가져오면 `tarraform.tfstate`에 저장된다.

## terraform plugin cache 설정  

1. provider 크기가 매우 크다.
2. 폴더마다 다운로드 받게되면 너무 큰 용량을 차지, 가령 AWS povider v5.8 이상은 630MB를 차지

그래서, 특정 디렉터리에 먼저 provider를 다운 받아놓고 서로 다른 terraform 코드들이 이 provider를 공유하는 방식이다.

```sh
echo "plugin_cache_dir"=\"$HOME/.terraform.d/plugin-cache\"" > ~/.terraformrc
```

## Terraform 블록
외울 필요는 없고, 대표적으로 다음이 있다.

1. resource: resource를 배포, 삭제, 수정하기 위해 사용하는 타입
2. data: 외부에 있는 데이터를 가져오기 위한 타입
3. variable: 변수를 사용하기 위한 타입
4. output: 출력하기 위한 타입

## Terrform 설치

아래의 페이지를 통해서 자세한 설치 방법을 알 수 있다.

https://developer.hashicorp.com/terraform/install

아래는 아마존 linux에서 설치하는 방법이다.
```sh
sudo yum install -y yum-utils shadow-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform
terraform -v
```

다음으로 terrafom cache를 위해서 terraformrc 파일을 설정해주도록 하자.

```sh
mkdir -p ~/.terraform.d/plugin-cache

cat <<EOF > ~/.terraformrc
plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"
EOF

cat ~/.terraformrc
```
이제 provider가 `~/.terraform.d/plugin-cache`에 설치될 것이다.

이제 제대로 동작하는 지 확인해보도록 하자.

- aws_caller_identity.tf
```tf
provider "aws" {
    region = "ap-northeast-2"
}

data "aws_caller_identity" "current" {}

output "test" {
    value = data.aws_caller_identity.current
}
```

`data`가 api 실행이고 그 결과를 `output`으로 전달하는 것이 전부이다. 참고로 `data`는 HTTP GET처럼 api를 실행해 data를 가져올 뿐, 수정, 삭제, 추가 등의 연산을 하진 않는다.

실행하기 이전에 provider를 설치해야하므로 해당 스크립트가 있는 path로가서,  `terrform init`을 실행해주도록 하자. 이 다음 `terraform plan`을 통해서 앞으로 어떤 동작이 실행될 지 확인할 수 있다.

이제 실행해보도록 하자.

```sh
terraform apply
yes
```
중간에 실행할 것인지 최종 허락을 받는데, `yes`라고 해주면 된다. 그러면 다음의 형식으로 데이터가 나온다.

```sh
test = {
  "account_id" = "xxxxxxxx"
  "arn" = "xxx:xxx:xxx::xxxxxxxx:assumed-role/xxxxxxxxxx/xxxxxxxxxx"
  "id" = "xxxxxxxxx"
  "user_id" = "xxxxxxxxx:xxxxxxxxx"
}
```
caller identtiy가 `test`라는 output에 잘 전달된 것을 볼 수 있다.

`ls -al`을 실행해서보면 `./terraform.tfstate`가 생긴 것을 볼 수 있다. 이는 마지막으로 기록된 값들을 정리해준 것이다.

## VPC 만들기
사용 방법은 terraform의 각 provider 예시를 보면서 하면 된다.

https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc

docs를 보면 `resource`와 `data source`가 있다. `data source`가 위에서 우리가 만든 `data` 블록 부분이랑 같다. 이 둘을 정리하면 다음과 같다.

1. resource: provider(AWS, GCP, Azure 등)의 리소스를 생성, 수정, 삭제한다. 가령 EC2, VPC, S3 생성
2. data: 리소스를 조회만 하는 API로 HTTP GET이랑 같다. 가령 `aws_ami`로 AMI 정보를 가져오는 것이 있다.

terraform 프로젝트 구조를 만들 때에는 다음의 일반적인 구성 방식을 따른다.

```sh
my-terraform-project/
├── main.tf          주요 리소스 정의 (핵심 인프라)
├── variables.tf     변수 정의
├── outputs.tf       출력 값 정의
├── provider.tf      provider 설정 (AWS, GCP 등)
├── terraform.tfvars 변수값 설정 (실제 값)
└── backend.tf       상태 저장소(S3 등) 정의
```
VPC라는 resource를 만들기 위해서는 `main.tf`에서 `resource` block에 정의를 하는 것이 핵심이 되는 것이다. 또한, `provider`는 한 번 해당 프로젝트에서 설정해놓았다면 또 설정할 필요는 없다.

- main.tf
```tf
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "test-vpc"
  }
}

output "our_vpc" {
    value = aws_vpc.this
}
```
`resource`에 `aws_vpc`리는 type을 지정한 것을 볼 수 있다. `aws_vpc`를 만들겠다는 것이고, 해당 vpc 객체를 여기서는 `this`라는 변수로 다루겠다는 것이다. 

vpc 객체의 결과를 `our_vpc` output에 지정한 것이다.

이제 실행해보도록 하자.

```sh
terraform init
terraform plan
```
`plan`까지 확인하면 어떠한 리소스들이 생성될 지 확실하게 볼 수 있다.

다음으로 실제 vpc를 만들어보도록 하자.
```sh
terraform apply
```

약간의 시간 후에 AWS console로 가면 `test_vpc`가 생성 되는 것을 볼 수 있다. 

`cat ./terraform.tfstate`으로 확인해보면 우리가 만든 `test_vpc`에 대한 자세한 정보가 정의된 것을 볼 수 있다.

삭제하는 것도 매우 간단한데, 다음의 명령어 하나면 된다.
```sh
terraform destroy
```
`yes`를 눌러주면 삭제된다.

`boto3`, `aws cli`로 aws resource를 관리하는 것보다 훨씬 간단한 것을 볼 수 있다.