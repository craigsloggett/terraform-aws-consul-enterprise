# tflint-ignore: terraform_required_version
module "consul_enterprise" {
  source = "craigsloggett/consul-enterprise/aws"
  # version = "x.x.x"
}
