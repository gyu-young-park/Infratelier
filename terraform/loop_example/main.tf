variable "users_count" {
  type = list(string)
  default = ["rex", "vincent", "june"]
}

resource "aws_iam_user" "this" {
  for_each = toset(var.users_count)
  name = each.key
  path = startswith(each.value, "/") ? each.value : "/"
}

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