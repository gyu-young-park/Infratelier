resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "dynamic-block-vpc"
  }
}

output "our_vpc" {
    value = aws_vpc.this
}