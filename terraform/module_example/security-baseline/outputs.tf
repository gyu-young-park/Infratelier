output "ebs_entrypted" {
  value = aws_ebs_encryption_by_default.this.enabled
}