resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

data "aws_ami" "microos_x86_snapshot" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_ami" "microos_arm_snapshot" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]
  }
}

resource "aws_key_pair" "k3s" {
  count      = var.aws_key_pair_name == null ? 1 : 0
  key_name   = var.cluster_name
  public_key = var.ssh_public_key
  tags       = local.labels
}

resource "aws_vpc" "k3s" {
  count                = local.use_existing_network ? 0 : 1
  cidr_block           = var.network_ipv4_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.labels, { Name = var.cluster_name })
}

data "aws_vpc" "k3s" {
  id = local.use_existing_network ? var.existing_network_id[0] : aws_vpc.k3s[0].id
}

# We start from the end of the subnets cidr array,
# as we would have fewer control plane nodepools, than agent ones.
resource "aws_subnet" "control_plane" {
  count             = length(var.control_plane_nodepools)
  vpc_id            = data.aws_vpc.k3s.id
  cidr_block        = local.network_ipv4_subnets[255 - count.index]
  availability_zone = var.network_region
  tags              = merge(local.labels, { Name = "${var.cluster_name}-cp-${count.index}" })
}

# Here we start at the beginning of the subnets cidr array
resource "aws_subnet" "agent" {
  count             = length(var.agent_nodepools)
  vpc_id            = data.aws_vpc.k3s.id
  cidr_block        = local.network_ipv4_subnets[count.index]
  availability_zone = var.network_region
  tags              = merge(local.labels, { Name = "${var.cluster_name}-ag-${count.index}" })
}

resource "aws_security_group" "k3s" {
  name   = var.cluster_name
  vpc_id = data.aws_vpc.k3s.id
  tags   = local.labels
}

resource "aws_security_group_rule" "rules" {
  for_each = { for idx, rule in local.firewall_rules_list : idx => rule }

  type              = rule.value.direction == "in" ? "ingress" : "egress"
  from_port         = lookup(rule.value, "port", 0)
  to_port           = lookup(rule.value, "port", 0)
  protocol          = rule.value.protocol
  cidr_blocks       = rule.value.direction == "in" ? lookup(rule.value, "source_ips", []) : lookup(rule.value, "destination_ips", [])
  security_group_id = aws_security_group.k3s.id
}

