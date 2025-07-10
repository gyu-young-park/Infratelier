terraform {
  backend "s3" {
    bucket = "my-backend-s3-bucket20250710144505068700000001"
    key = "subnet/terraform.tfstate"
    region = "ap-northeast-2"
  }
}