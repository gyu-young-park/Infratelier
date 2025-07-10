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
`resource`에 `aws_vpc`리는 type을 지정한 것을 볼 수 있다. `aws_vpc`를 만들겠다는 것이고, 해당 vpc 객체를 여기서는 `this`라는 변수로 다루겠다는 것이다. 즉, `this`는 여기서만 쓰이는 로컬 네임이다.

`this`는 `aws_vpc` resource type의 인스턴스 같은 것이므로, `aws_vpc.this`로 접근이 가능하다.

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

## 변수
변수를 통해서 테라폼의 코드를 더욱 효율적으로 만들 수 있다. 변수를 선언하기 위해서는 `variable`이라는 지시자를 사용한다.

단, terraform의 변수는 초기에 설정된 값에서 동적으로 바뀌지 않는다. 즉, immutable하다고 생각하면 된다. 또한, 다른 변수의 값을 참조하지 못하는데, 이는 상수값 즉, literal한 값만 받을 수 있다는 한계가 있다. 이를 해결하기 위해서 나중에 `locals`에 대해서 알아보자.

```tf
variable "string_var" {
  description = "string variable"
  type = string
  default = "rex"
}

output "string_output" {
  value = var.string_var
}
```

`variable`로 `string_var` 변수를 선언하고 `default`값은 `rex`이고 `type`은 문자열이라는 것이다. 참고로 `type`과 `description`은 권장 사항이지만 써주는 것이 좋다.

이 `string_var` 변수를 사용하기 위해서 `var.string_var`이라고 쓴 것을 볼 수 있다.

변수에 초기값을 집어넣는 방법은 3가지 방법이 있다.
1. default
2. 환경 변수: `TF_VAR_변수명=변수값` 형식을 사용하면 된다. 위의 예제의 경우는 `TF_VAR_string_var=hello`라고 하는 방법이 있다.
3. .tfvars 파일 사용: `terraform.tfvars`에 `string_var="hello"`라고 정의하면 적용된다.

적용 순서는 `.tfvars`를 참조하고 `TF_VAR_변수명` 다음에 `default`가 적용된다.

## 자료형
테라폼은 다양한 종류의 자료형을 지원하는데, 자료형들은 혼합하여 새로운 데이터 구조를 만들 수 있다. 

1. `string`

```tf
variable "string_var" {
    description = "string variable"
    type = string
    default = "rex"
}

output "string_var" {
    value = var.string_var
}
```

2. `number`

```tf
variable "number" {
    type = number
    default = 1
}
```

3. `bool`

```tf
variable "bool" {
    type = bool
    default = false
}

output "bool" {
    value = var.bool
}
```

4. `list`: list의 경우 element의 type을 하나만 사용할 수 있다. `list(number)`과 같이 `type`을 만들 수 있고, `var.list[0]`과 같이 인덱싱 연산이 가능하다.

```tf
# terraform의 list는 하나의 타입만 가질 수 있다.
variable "list" {
    type = list(number)
    default = [ 1,2,3,4 ]
}

output "list" {
    value = var.list[0]
}
```

5. `tuple`: 여러 type을 하나의 tuple로 만들 수 있다. `tuple([number, string, bool])`처럼 사용할 수 있고 인덱싱 연산이 가능하다.

```tf
# tuple은 여러 타입을 하나의 구조체 처럼 묶는다.
variable "tuple" {
    type = tuple([number, string, bool])
    default = [ 1, "str", false ]
}

output "tuple" {
  value = var.tuple
}
```

6. `set`: 중복된 값을 가질 수 없다. `set(string)`으로 사용 가능하지만 인덱싱 연산이 불가능하다.

```tf
# 중복된 값을 허용하지 않는다.
variable "set" {
    type = set(string)
    default = ["aa", "a", "aa"]
}

output "set" {
  value = var.set
  # value = var.set[0] # indexing 불가능
}
```
인덱싱 연산이 불가능하기 때문에 index 연산이 가능한 list로 변환이 가능하다.
```tf
# set -> list
output "tolist" {
    value = tolist(var.set)[0] # indexing 가능
}

# list -> set
output "toset" {
  value = toset(var.list)
}
```

7. `map`: key는 string이고 value type은 지정하면 된다. `map(number)` 이렇게 선언 시에 value type이 number이다.

```tf
variable "map" {
    type = map(number)
    default = {
      "rex" = 1
      "vincent" = 2
      "gyu" = 3
    }
}

output "map" {
    value = var.map
    # value = var.map["rex"]
    # valur = var.map.rex 
}
```

8. object: 1~7까지의 원시 타입을 기반으로 하나의 구조체를 만들어 낼 수 있다. 마치 json을 생각하면 된다.
```tf
variable "vpc_var" {
    type = object({
      cidr = string
      dns = bool
      hostname = bool
    })

    default = {
      cidr = "10.0.0.0/16"
      dns = true
      hostname = true
    }
}

output "vpc_var" {
  value = var.vpc_var
  # value = var.vpc_var["cidr"]
  # value = var.vpc_var.cidr
}
```

이렇게 만든 `vpc_var`이라는 변수를 사용하여 vpc resource를 만들 때 사용할 수 있다.
```tf
resource "aws_vpc" "this" {
    cidr_block = var.vpc_var.cidr
    enable_dns_hostnames = var.vpc_var.hostname
    enable_dns_support = var.vpc_var.dns

    tags = {
      "Name" = "${var.string_var}-vpc" 
    }
}
```
shell에서 보듯이 `"${var.string_var}-vpc"`와 같이 문자 데이터 삽입이 가능하다. 

`terraform plan`을 사용하면 어떤 식으로 변수들이 output에 나오는 지 확인 할 수 있다. 예제 variable_example`에 있는 `main.tf`을 실행하면 다음과 같이 나온다.

```sh
  # aws_vpc.this will be created
  + resource "aws_vpc" "this" {
      + arn                                  = (known after apply)
      + cidr_block                           = "10.0.0.0/16"
      + default_network_acl_id               = (known after apply)
      + default_route_table_id               = (known after apply)
      + default_security_group_id            = (known after apply)
      + dhcp_options_id                      = (known after apply)
      + enable_dns_hostnames                 = true
      + enable_dns_support                   = true
      + enable_network_address_usage_metrics = (known after apply)
      + id                                   = (known after apply)
      + instance_tenancy                     = "default"
      + ipv6_association_id                  = (known after apply)
      + ipv6_cidr_block                      = (known after apply)
      + ipv6_cidr_block_network_border_group = (known after apply)
      + main_route_table_id                  = (known after apply)
      + owner_id                             = (known after apply)
      + region                               = "ap-northeast-2"
      + tags                                 = {
          + "Name" = "rex-vpc-10"
        }
      + tags_all                             = {
          + "Name" = "rex-vpc-10"
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + bool       = false
  + list       = 1
  + map        = {
      + gyu     = 3
      + rex     = 1
      + vincent = 2
    }
  + set        = [
      + "a",
      + "aa",
    ]
  + string_var = "rex"
  + tolist     = "a"
  + toset      = [
      + 1,
      + 2,
      + 3,
      + 4,
    ]
  + tuple      = 1
  + vpc_var    = {
      + cidr     = "10.0.0.0/16"
      + dns      = true
      + hostname = true
    }
```

우리가 설정한 변수들이 잘 나온 것을 볼 수 있다.

## Local values
변수는 상수만 입력이 가능하고 다른 변수를 참조하지 못할 뿐더러 동적으로 수정이 안되는 immutable한 성질이 있다고 했다. 즉 다음과 같은 상황에서 에러가 발생한다.

```tf
variable "prefix_test" {
  default = "${var.prefix}-${var.common}"
}
```

변수에는 다음의 한계가 있다.
1. 변수는 배포 중에 동적인 생성이나 수정이 불가
2. 다른 변수를 참조하거나 조합한 새로운 변수를 만들 수 없다.
3. 조건문이나 함수 활용이 불가
4. 또한, 데이터 소스를 활용하는 경우 값을 변수에 할당 불가

결국 변수만으로는 코드 중복을 막을 수 없고, 유지보수의 어려움이 생긴다.

그래서 이러한 문제를 해결하기 위해서 `local values`가 나오게 되었다.

```tf
locals {
  prefix_test = "${var.prefix}-${var.common}"
  prefix_prod = "${var.prefix}-prod"
}

resource "aws_iam_user" "test3" {
  name = "${local.prefix_test}-user"
}
```
물론 `resource`에 쓸 때 locals를 안쓰고 `name = "${var.prefix}-${var.common}-user"`로 써줘도 같은 기능을 하는 코드이지만, 유지 보수가 어렵고 프로그래밍 불가능하다는 단점이 있다.

또한, `locals`를 사용하면 data source를 사용해서 결과값을 저장하는 것도 가능하다.

```tf
data "aws_caller_identity" "current" {}

### 불가능
variable "account_id" {
  default = data.aws_caller_identity.current.account_id
}
```
다음의 경우 `variable`로 `aws_caller_identtiy`값을 `account_id`로 저장하는 코드인데, 이는 실패한다. 

위의 코드를 아래와 같이 `locals`를 사용하도록 수정하면 `account_id`에 결과가 저장되는 것을 볼 수 있다.
```tf
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}
```

## Builtin functions
https://developer.hashicorp.com/terraform/language/functions

위의 링크에 들어가면 terraform built-in function 관련 공식 문서를 볼 수 있다. 

숫자, 문자열, 집합, 인코딩, 파일 등 다양한 함수들이 존재한다.

다음의 예제는 다양한 built-in 함수의 사용을 보여준다.
```tf
variable "prefix" {
    default = "company"
}

variable "common" {
    default = "test"
}

# 문자열 분리
locals {
  prefix_test = "${var.prefix}-${var.common}"
  prefix_prod = "${var.prefix}-prod"
  splited_prefix = split("-", local.prefix_test)[0]
}

output "splited_prefix" {
  value = local.splited_prefix
}

# 길이 출력
output "length" {
  value = length([1,2,3])
}

# list 합치기
output "concat" {
  value = concat(["a", ""], ["b", "c"])
}
```

`terraform plan`으로 결과를 확인하면 다음과 같다.
```sh
Changes to Outputs:
  + concat         = [
      + "a",
      + "",
      + "b",
      + "c",
    ]
  + length         = 3
  + splited_prefix = "company"
```
빌트인 함수들이 잘 적용된 것을 볼 수 있다.

참고로 terraform에서 사용자 정의 함수는 제공하지 않는다.

## 반복문
반복문은 두 가지가 있다. `count`, `for_each` 둘이 있다.

1. 리소스 또는 모듈 블록을 반복하기 위해 사용한다.
2. 유저 100개를 만들기 위해 리소스 100개를 모두 코드에 넣기보다는 반복문을 사용한다.
3. `count`
  1. 명시된 개수만큼 리소스를 생성한다.
  2. 생성된 순서(index)를 기준으로 리소스 존재 유뮤를 판단한다.
4. `for_each`
  1. python의 dict와 비슷하다.
  2. 키의 개수를 기준으로 반복을 수행한다.
  3. count와 달리 인덱스가 아닌 키가 리소스 존재 유무를 판단하는 기준이 된다.

`count` 사용법은 다음과 같다.

```tf
resource "aws_iam_user" "this" {
  count = 3
  name  = "rex-${count.index}"
}

output "users" {
  value = aws_iam_user.this
  # value = aws_iam_user.this[0].arn
  # value = aws_iam_user.this[*].arn
}
```
`count`를 3으로 주었으므로 0,1,2로 순회해서 `resource`를 생성한다. `aws_iam_user.this[*]`로 전체 데이터를 list로 받아올 수도 있다.

count의 문제점이 있는데, 다음을 보도록 하자.

```tf
variable "users" {
  type = list(string)
  default = ["rex", "vincent", "june"]
}

resource "aws_iam_user" "this" {
  count = length(var.users)
  name = "${var.users[count.index]}-${count.index}"
}
```
`var.users`에 있는 데이터 수인 3만큼 순회하게 되고, 3개의 IAM 유저를 만들게 된다. 즉, `rex-0`, `vincent-1`, `june-2`도 사라진다.

그런데, 만약 가운데의 `vincent`를 삭제한다고 하자. 이때 문제가 발생하는데, `vincenet`만 지우고 다시 실행해버리면 `aws`에서 `june-2`를 삭제해버리고 `june-1`을 생성한다. 정리하면 `vincent-1`이 `june-1`로 바뀌었다고 생각해서 `vincent-1`을 삭제하고 `june-1`을 만들지만 `june-2`까지 순회가 돌지 않으므로 이전에 만든 `june-2`는 삭제해버리는 것이다.

이는 현재 상태 정보와의 차이로 인해 발생한 것이다. 따라서, count 사용은 조심해야한다.

count를 사용하는 경우는 다음과 같다.
1. 단순 반복이 필요할 때
2. 리소스의 고유성이 중요하지 않을 때
3. 조건 표현식(conditional expressions)을 통해 리소스 생성 여부를 결정할 떄

고유성이 중요하면 `for_each`를 사용해서 '키'가 존재하는 자료형이나 데이터를 사용하여 반복시키도록 한다. 

```tf
variable "users" {
  type = list(string)
  default = ["rex", "vincent", "june"]
}

resource "aws_iam_user" "this" {
  for_each = toset(var.users)
  name = each.key
  path = startswith(each.value, "/") ? each.value : "/"
}
```
`for_each`로 반복을 돌게된다. `set`의 경우 key-value가 따로 있는게 아니라, key-value가 동일한 값이다. 따라서, `each.key`랑 `each.value`랑 같다.

이렇게 만들면 배열에서 `vincent`를 지워도 `june` 리소스가 사리지지 않는다. 즉, `count`에서 발생하는 문제가 생기지 않는다는 것이다.

`object`로 key-value를 지정해서 사용할 수도 있다.
```tf
variable "users_object" {
  type = object({
    rex1 = string
    vincent = string
    june = string
  })

  default = {
    rex1 = "/good/"
    vincent = "/bad/"
    june = "hmm/"
  }
}

resource "aws_iam_user" "this2" {
  for_each = var.users_object
  name = each.key
  path = each.value
}
```

`terraform plan`으로 보면 다음과 같다.

```sh
# aws_iam_user.this2["june"] will be created
  + resource "aws_iam_user" "this2" {
      + arn           = (known after apply)
      + force_destroy = false
      + id            = (known after apply)
      + name          = "june"
      + path          = "hmm/"
      + tags_all      = (known after apply)
      + unique_id     = (known after apply)
    }

  # aws_iam_user.this2["rex1"] will be created
  + resource "aws_iam_user" "this2" {
      + arn           = (known after apply)
      + force_destroy = false
      + id            = (known after apply)
      + name          = "rex1"
      + path          = "/good/"
      + tags_all      = (known after apply)
      + unique_id     = (known after apply)
    }

  # aws_iam_user.this2["vincent"] will be created
  + resource "aws_iam_user" "this2" {
      + arn           = (known after apply)
      + force_destroy = false
      + id            = (known after apply)
      + name          = "vincent"
      + path          = "/bad/"
      + tags_all      = (known after apply)
      + unique_id     = (known after apply)
    }
```
고유성이 있는 경우 object나 set, map 처럼 key-value 기반의 순회가 훨씬 더 안정적이고 예상 가능한 결과가 나온다.

## 표현식
값을 반환하는 식을 의미한다. python의 list comprehension같은 것처럼 terraform에는 다음의 expression이 있다.

1. Conditional Expressions
2. For Expressions
3. Splat Expressions

`Splat Expressions`은 이전에 배운 list나 Map처럼 순회 가능한 자료구조에서 `[*]`와 같이 여러 값을 한꺼번에 꺼내거나 어떤 필드를 꺼낼 때 사용하는 것을 말한다. 따라서, Conditional Expressions와 For Expressions에 대해서 알아보자.

먼저 conditional expressions에 대해서 알아보자
```tf
variable "need_group" {
  default = false
}

resource "aws_iam_group" "this" {
    count = var.need_group ? 1 : 0
    name = "this_is_my_group"
    path = "/"
}
```
`count = var.need_group ? 1 : 0`이 부분을 보면 `var.need_group`이 true이면 count가 1이므로 `aws_iam_group`을 만들고, false이면 안만드는 것이다. `count`와 `conidtional expression`을 함께 조합해서 이렇게 잘 사용한다.

단, 조심할 것은 `count`를 사용했기 때문에 `output`에 `this`는 list 형식이라는 것을 잊지 말도록 하자.

`for expression`은 다음과 같이 쓸 수 있다.

```tf
variable "users" {
  default = ["rex", "vincent", "june"]
}

resource "aws_iam_user" "count" {
  for_each = toset([for user in var.users : user])
  name = each.key
  path = "/"
}
```
`for user in var.users : user`이 바로 `for expression`이다. `user`가 각 iteration에서 쓸 `user` 데이터인 것이다.

`for expression`은 더 나아가서 순회를 돌면서 `if`문도 사용할 수 있다.

```tf
resource "aws_iam_user" "count" {
  for_each = toset([for user in var.users : user if user != "vincent"])
  name = each.key
  path = "/"
}
```
`vincent`가 아닌 경우만 추가하는 코드를 만들 수 있다.

또한, object에 대해서 key-value 형식으로 `for expression`도 가능하다.

```tf
variable "users_with_path" {
    default = {
        rex = "/admin/"
        vincent = "/admin/"
        june = "/users/"
    }
}

resource "aws_iam_user" "for_kv" {
    for_each = { for k, v in var.users_with_path : k => v if k != "june"}
    name = each.key
    path = each.value
}
```
이번에는 `for expression`이 살짝 다른데, `k => v`로 써주어야 한다. 이러한 부분들은 외우지 말고 기억만했다가, 나중에 참고해서 쓰면 된다. 여기서는 `june`이 아닌 경우에만 `aws_iam_user`를 만들도록 한 것이다.

## Dynamic Blocks
다음의 코드를 보도록 하자.

```tf
resource "aws_vpc" "this" {
    cidr_block = "10.0.0.0/16"
    tags = {
      Name = "dynamic-block-vpc"
    }
}

resource "aws_security_group" "allow_http_https" {
    name = "allow_http_https"
    vpc_id = aws_vpc.this.id

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
```
vpc를 만들고 security group을 설정하는 부분이다. `name`, `vpc_id`와 같은 경우는 하나의 attribute이지만 `ingress`와 같은 것은 sub block으로 set이나 map처럼 여러 번 쓸 수 있거나 object와 같은 형식을 가진다.

지금은 `ingress`로 security group의 인바운드 룰을 하나하나 설정하고 있지만, 이것이 여러 개를 설정해야할 때면 하나하나 설정해주는 것이 힘들 때가 있다. 이를 위해서 terraform에서는 여러 번 입력해야하는 sub block들을 위해서 `dynamic blocks`를 제공한다. 

```tf
variable "ingress_rules" {
  description = "List of ingress rules"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

resource "aws_security_group" "allow_http_https" {
    name = "allow_http_https"
    vpc_id = aws_vpc.this.id

    dynamic "ingress" {
      for_each = var.ingress_rules
      content {
        from_port = ingress.value["from_port"]
        to_port = ingress.value["to_port"]
        protocol = ingress.value["protocol"]
        cidr_blocks = ingress.value["cidr_blocks"]
      }
    }
}
```
`ingress_rules`을 dynamic block이 순회하면서 `ingress` sub block에 대한 데이터들을 입력해준다. 재밌는 것은 `ingress_rules` 변수의 각 item에 접근할 때 `dynamic` block의 이름으로 접근한다는 것인데, 여기서는 `ingress`으로 `ingress.value["from_port"]` 이렇게 접근하는 것을 볼 수 있다.

## 멀티 프로바이더
1. 하나의 폴더에서 여러 리전 또는 여러 계정에 배포하고 싶을 때 사용
2. 보안 관련 리소스 특성 상 한 번에 배포해야 하는 케이스가 많다.
  1. Macie, GuardDuty, Inspector emd
  2. 리전 또는 계정 외 형상이 비슷한 경우에 고려 가능
3. 다양한 종류의 프로바이더를 사용하는 것 또한 '멀티'라고 볼 수 있지만 보통은 동일 프로바이더를 대상으로 말한다.

다음의 예제를 보도록 하자.
```tf
# default Provider
provider "aws" {
    region = "us-east-1"
}

# alias로 provider 구분
provider "aws" {
    region = "ap-northeast-2"
    alias = "apne2"
}

resource "aws_vpc" "use1" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "use1-dynamic-block-vpc"
    }  
}

# multi provider 사용 시
# provider를 꼭  명시
resource "aws_vpc" "apne2" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "apne2-dynamic-block-vpc"
    }  

    provider = aws.apne2
}
```
두 개의 리전이 있는 것을 볼 수 있다.
1. `us-east-1`은 default region이다.
2. `ap-northeast-2`은 두 번재 region이고 구분하기위해서 alias로 `apne2`을 주었다. 

`apne2`를 resource 블럭에서 `provider`라는 attribute를 주면 된다.

조심해야할 것은 만약 provider에 대한 수정 사항이 있다면 반드시 기존의 resource를 삭제하고 수정하는 것이 좋다. 왜냐하면 provider를 지정한 값을 다른 값으로 바꾸면 이전 provider에서 생성했던 resource들이 삭제되지 않는다. 

참고로 이렇게 multi provider 상황에서 특정 provider가 적용된 resource만 없애고 싶을 수 있다. 이 경우 terraform 명령어에서 `-terget` 옵션을 주면 된다.

```sh
terraform destroy -target=aws_vpc.apne2
```
`aws_vpc` resource 중에서 `apne2`라는 이름을 가진 resource만 없앤다는 것이다. `aws_vpc.use1`은 삭제되지 않고 남는다.

## Default tags
tag는 resource에 tag를 두어 메타 데이터를 명시하는 것이다. resource들을 만들다보면 tag들이 동일한 경우들이 많았는데, 예전에는 다음과 같았다.

```tf
provider "aws" {
    region = "ap-northeast-2"
}

locals {
  tags = {
    name = "rex11"
  }
}

resource "aws_iam_user" "this" {
  name = "rex"
  tags = local.tags
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/24"
  tags = local.tags
}
```
`locals`에 `tags`라는 map을 만들어 설정한 다음에 `resource`에 tags마다 `local.tags`를 명시하는 것이다. 그러나 이는 리소스 수가 많아지면 매번 tags를 설정해야하는 문제가 있고, tags 설정을 누락할 때가 생길 수 밖에 없다.

그래서 terraform에서는 default tag라는 것을 만들었다. 직접 명시하지 않고 `provider`부분에 `default_tags`를 써주면 모든 리소스에 해당 `default_tags` 정보가 입력된다.

```tf
provider "aws" {
    region = "ap-northeast-2"
    default_tags {
      tags = {
        Name = "rex"
        Team = "Cloud" 
      }
    }
}

resource "aws_iam_user" "this" {
  name = "rex"
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/24"
}
```
aws provider에 `default_tags`로 기본 tag를 설정할 수 있다. 만약 `tags`를 `default_tags`가 아닌 다른 값으로 입력하고 싶다면, 직접 입력하면 된다.

## lifecycle
https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle

다양한 lifecycle meta-arguments들이 있지만 우리는 두 가지만 알아보도록 하자.

VPC, EC2와 같은 resource가 배포가 되었있다고 하자. 그런데 사용자가 실수로 terraform으로 삭제할 수 있는데, 삭제하지 못하도록 `lifecycle`을 설정할 수 있다.

- main.tf
```tf
resource "aws_vpc" "thus" {
    cidr_block = "10.0.0.0/16"
    tags = {
      Name = "dynamic-block-vpc"
    }

    lifecycle {
      prevent_destroy = true
    }
}
```
삭제 명령어를 실행하면 error가 발생하게 된다.

```
Error: Instance cannot be destroyed
```
이는 실수로 resource를 잘못 삭제하는 경우를 막기 위함이다. 삭제하고 싶다면 lifecycle 부분을 수정하는 수 밖에 없다. 중요한 resource는 반드시 lifecycle로 `prevent_destroy`를 걸어놓도록 하자.

lifecycle의 또 다른 경우로는 특정 속성이 변해도 반영하지 않도록 하고 싶을 때가 있다. 

```tf
resource "aws_iam_user" "this" {
  name = "rex123"
  tags = {
    Team = "cloud"
  }
}
```
다음은 `aws_iam_user` resource를 배포하는 코드인데, tag로 `Team=cloud`를 주었다. 그런데, 시간이 지나서 tag가 바뀌었다고 하자. 문제는 tag가 바뀌었다고 기존에 만들어 두었던 `rex123`에는 변동사항을 반영하고 싶지 않고 싶을 수 있다. 왜냐하면 tag같은 경우 바뀌면 좋지만 바뀐 것을 감지하고 리소스를 다시 올리기에는 그렇게 중요한 속성은 아니기 때문이다.

또한, `rex123`의 tag 정보를 누군가가 console에서 수정했다고 하자. terraform의 경우 remote와도 sync를 맞추기 때문에 변화를 감지하고 changed 상태로 변동된다. 

이 처럼 일부 속성에 대하여 변동 사항을 반영하고 싶지 않다면 다음과 같이 사용하면 된다.
```tf
resource "aws_iam_user" "this" {
  name = "rex123"
  tags = {
    Team = "cloud"
  }

  lifecycle {
    ignore_changes = [ tags ]
  }
}
```
`ignore_changes`안에 무시할 속성을 입력하면 `tags`값이 바뀌어도 `rex123`에 반영하지 않는다.

이 밖에도 lifecycle은 다양한 기능들이 있어 필요할 때마다 찾아서 쓰면 된다. 가령 특정 값이 바뀌면 새롭게 교체하도록 하는 일도 있다.

## Remote State
테라폼에서 backend는 테라폼의 상태 파일을 관리하는 장소를 말한다.

1. 상태(terraform.tfstate)는 내가 무엇을 배포했고, 관리할 지에 대한 타겟이기 때문에 생명과도 같다.
2. 이러한 파일이 관리되는 위치를 backend라고 한다.
3. 기본적으로 동일 폴더인 local에 만들어지지만 s3, GCS 등 원격에 저장이 가능하다.
4. 이렇게 원격으로 저장함으로서 다음을 얻을 수 있다.
  1. 우발적 삭제 방지
  2. 버저닝을 통한 상태 변경 기록 자동 백업
  3. 소스코드만 공유하더라도 협업 가능

`terraform_remote_state`라는 data를 통해서 tfstate 파일을 가져올 수 있다. 아래는 s3에서 tfstate 파일을 가져오는 것이다.

```tf
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "terraform-state-pod"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}
```

테스트를 위해 s3 bucket을 만드는 terraform script부터 만들어보도록 하자.
```tf
resource "aws_s3_bucket" "this" {
    bucket_prefix = "my-backend-s3-bucket"
    force_destroy = true
}

resource "aws_s3_bucket_versioning" "this" {
    bucket = aws_s3_bucket.this.id
    versioning_configuration {
      status = "Enabled"
    }
}

output "bucket_name" {
  value = aws_s3_bucket.this.bucket
}
```
`aws_s3_bucket`으로 s3를 사용할 수 있다. 참고로 `force_destroy`을 `true`로 설정해주면 bucket 삭제 시에 bucket 안에 있는 데이터들도 모두 삭제된다.

`aws_s3_bucket_versioning`을 설정해주면 버전에 따라 같은 키값이 해당 버전에 맞는 값을 갖게된다. 따라서, 버저닝을 통해 이전 값을 백업 할 수 있는 것이다.

`terraform apply`로 실행시켜 결과를 보도록 하자. 

제대로 실행되었다면 output으로 버킷 이름이 만들어졌을 것이다. 필자의 경우는 `my-backend-s3-bucket20250710144505068700000001`이 나왔다. 이 상태에서 backend를 사용해서 tfstate를 저장하도록 하자.

- vpc/_backends.tf
```tf
terraform {
  backend "s3" {
    bucket = "my-backend-s3-bucket20250710144505068700000001"
    key = "vpc/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
```
위와 같이 `_backends.tf`을 설정하면 `vpc/terraform.tfstate`을 사용하고, s3에 업로드까지 해주도록 한다.

- vpc/main.tf
```tf
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "dynamic-block-vpc"
  }
}

output "our_vpc" {
    value = aws_vpc.this
}
```

`terraform apply`로 배포해보도록 하자. 다음과 같은 에러가 발생할 수 있다.

```sh
│ Error: Backend configuration changed
```

이는 backend로 사용할 설정이 local에서 s3로 변경되었기 때문이다. 이때에는 `terraform init -migrate-state`으로 backend를 다른 곳으로 사용하겠다고 명시적으로 적어주면 된다.

`terrform init`이 성공했다면 `terraform apply`를 실행해주도록 하자.

실행시켜주면 우리가 만든 s3 bucket에 object가 생긴 것을 볼 수 있다. 해당 object를 보면 terrform.tfstate를 가지는 것을 볼 수 있다.

다음으로 subnet을 하나 만들되 s3에 있는 vpc terraform.tfstate를 사용해보기로 하자. 이미 tfstate에 vpc관련 정보가 있기 때문에 subnet을 만들 때의 vpc id를 할당해줄 수 있다.

- subnet/_backends.tf
```tf
terraform {
  backend "s3" {
    bucket = "my-backend-s3-bucket20250710144505068700000001"
    key = "subnet/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
```
동일한 bucket이지만 key는 다른 것을 볼 수 있다. subnet이기 때문에 `subnet/terraform.tfstate`으로 subent의 terraform.tfstate를 저장할 것이다.

다음으로 vpc에 대한 정보를 `vpc/terraform.tfstate`에서 가져오도록 하자.

- _remotes.tf
```tf
data "terraform_remote_state" "vpc" {
    backend = "s3"
    config = {
        bucket = "my-backend-s3-bucket20250710144505068700000001"
        key = "vpc/terraform.tfstate"
        region = "ap-northeast-2"
    }
}
```
`_remotes.tf`는 `vpc/terraform.tfstate`에 대한 정보를 `vpc`라는 data로 가져오는 것이다. 

`vpc/terraform.tfstate` 정보를 가져왔지만 output을 뽑아 vpc id를 얻는 과정을 간편하게 하기 위해서 `_locals.tf`를 만들어 local 변수로 만들도록 하자. 이는 실무에서 많이 사용되는 패턴이다.

- _locals.tf
```tf
locals {
  vpc_id = data.terraform_remote_state.vpc.outputs.our_vpc.id
}
```
우리가 만든 vpc의 정보가 `our_vpc`에 저장되어 있고, id값을 갸져와 `vpc_id`에 저장한 것이다.

다음으로 `main.tf`를 만들어 subnet을 만들어보자.

- main.tf
```tf
resource "aws_subnet" "this" {
  vpc_id = local.vpc_id
  cidr_block = "10.0.1.0/24"
}

output "subnet_id" {
  value = aws_subnet.this.id
}
```
이제 `terraform init`과 `terraform apply`로 배포해주도록 하자.

배포 완료 후에 `subnet_id = "subnet-080419eb6ad098d6d"`이 만들어진 것을 볼 수 있다. 또한, s3에 `subnet/terraform.tfstate`가 만들어진 것도 볼 수 있다.

이렇게 local이 아닌 원격으로 tfstate를 관리하여 관리의 편의성을 증대 시킬 수 있다.

단, 삭제 순서를 지켜서 삭제하는 수 밖에 없는데, 이 과정이 좀 껄끄럽다. 우리의 경우는 subnet -> vpc -> s3 순서로 삭제해야한다. 또한, s3를 프로비저닝한 terraform의 경우는 tfstate 파일이 원격이 아니라 로컬에 남을 수 밖에 없다. 물론, 이 파일 마저도 다른 외부로 관리할 수도 있다.

backend는 local, s3 뿐만 아니라 다양한 방식들이 있다. 해당 링크를 참조해서 각자의 상황에 맞게 만들어보도록 하자. https://developer.hashicorp.com/terraform/language/backend

## 