data "aws_route53_zone" "selected" {
  name = var.route53_zone_name
}

data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-13-amd64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "consul" {
  # tflint-ignore: terraform_module_pinned_source
  source = "git::https://github.com/craigsloggett/terraform-aws-consul-enterprise"

  project_name              = "consul-enterprise"
  route53_zone              = data.aws_route53_zone.selected
  consul_enterprise_license = var.consul_enterprise_license
  ec2_key_pair_name         = var.ec2_key_pair_name
  ec2_ami                   = data.aws_ami.debian
}
