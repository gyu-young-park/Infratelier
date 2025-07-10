module "baseline" {
    source = "../security-baseline"
    // input variables
}

output "ebs_entrypted" {
  value = module.baseline.ebs_entrypted
}