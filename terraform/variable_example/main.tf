variable "string_var" {
    description = "string variable"
    type = string
    default = "rex"
}

output "string_var" {
    value = var.string_var
}

variable "number" {
    type = number
    default = 1
}

variable "bool" {
    type = bool
    default = false
}

output "bool" {
    value = var.bool
}

# terraform의 list는 하나의 타입만 가질 수 있다.
variable "list" {
    type = list(number)
    default = [ 1,2,3,4 ]
}

output "list" {
    value = var.list[0]
}

# tuple은 여러 타입을 하나의 구조체 처럼 묶는다.
variable "tuple" {
    type = tuple([number, string, bool])
    default = [ 1, "str", false ]
}

output "tuple" {
  value = var.tuple
}

# 중복된 값을 허용하지 않는다.
variable "set" {
    type = set(string)
    default = ["aa", "a", "aa"]
}

output "set" {
  value = var.set
  # value = var.set[0] # indexing 불가능
}

# set -> list
output "tolist" {
    value = tolist(var.set)[0] # indexing 가능
}

# list -> set
output "toset" {
  value = toset(var.list)
}

# string이 key이고 value 타입만 정해주면 된다.
variable "map" {
    type = map(number)
    default = {
      "rex" = 1
      "vincent" = 2
      "gyu" = 3
    }
}

output "map" {
    value = var.map
    # value = var.map["rex"]
    # valur = var.map.rex 
}

# object타입을 통해서 새로운 구조체를 만들 수 있다.
variable "vpc_var" {
    type = object({
      cidr = string
      dns = bool
      hostname = bool
    })

    default = {
      cidr = "10.0.0.0/16"
      dns = true
      hostname = true
    }
}

output "vpc_var" {
  value = var.vpc_var
  # value = var.vpc_var["cidr"]
  # value = var.vpc_var.cidr
}

resource "aws_vpc" "this" {
    cidr_block = var.vpc_var.cidr
    enable_dns_hostnames = var.vpc_var.hostname
    enable_dns_support = var.vpc_var.dns

    tags = {
      "Name" = "${var.string_var}-vpc" 
    }
}