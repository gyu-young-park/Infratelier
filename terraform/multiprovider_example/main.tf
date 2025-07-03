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