variable "prefix" {
  default = "company"
}

variable "common" {
  default = "test"
}

### 불가능
# variable "prefix_test" {
#   default = "${var.prefix}-${var.common}"
# }

locals {
  prefix_test = "${var.prefix}-${var.common}"
  prefix_prod = "${var.prefix}-prod"
}

output "test" {
    value = local.prefix_test
}

data "aws_caller_identity" "current" {}

### 불가능
# variable "account_id" {
#   default = data.aws_caller_identity.current.account_id
# }

locals {
  account_id = data.aws_caller_identity.current.account_id
}

output "account_id" {
    value = local.account_id
}

resource "aws_iam_user" "test3" {
    name = "${local.prefix_test}-user"
}