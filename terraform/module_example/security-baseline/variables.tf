variable "ebs_entrypted" {
  type = bool
  default = true
}

variable "aws_ebs_snapshot_block_public_access" {
    type = string
    default = "block-all-sharing"
}

variable "min_pass_len" {
    type = number
    default = 10
}