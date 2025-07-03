variable "need_group" {
  default = false
}

resource "aws_iam_group" "this" {
    count = var.need_group ? 1 : 0
    name = "this_is_my_group"
    path = "/"
}