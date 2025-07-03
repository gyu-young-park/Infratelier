variable "users" {
  default = ["rex", "vincent", "june"]
}

resource "aws_iam_user" "count" {
  for_each = toset([for user in var.users : user])
  name = each.key
  path = "/"
}

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
