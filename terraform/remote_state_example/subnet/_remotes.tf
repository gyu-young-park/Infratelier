data "terraform_remote_state" "vpc" {
    backend = "s3"
    config = {
        bucket = "my-backend-s3-bucket20250710144505068700000001"
        key = "vpc/terraform.tfstate"
        region = "ap-northeast-2"
    }
}