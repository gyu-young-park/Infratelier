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