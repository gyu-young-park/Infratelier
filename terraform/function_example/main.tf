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