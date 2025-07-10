locals {
  vpc_id = data.terraform_remote_state.vpc.outputs.our_vpc.id
}