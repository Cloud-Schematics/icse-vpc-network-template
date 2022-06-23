##############################################################################
# Create VPC
##############################################################################

resource "ibm_is_vpc" "vpc" {
  name                        = var.vpc_name == null ? "${var.prefix}-vpc" : var.vpc_name
  resource_group              = var.resource_group_id
  classic_access              = var.classic_access
  address_prefix_management   = var.use_manual_address_prefixes == false ? null : "manual"
  default_network_acl_name    = var.default_network_acl_name
  default_security_group_name = var.default_security_group_name
  default_routing_table_name  = var.default_routing_table_name
  tags                        = var.tags
}

##############################################################################


##############################################################################
# Create VPC Default Security Group Rules
##############################################################################

module "default_security_group_rules" {
  source               = "github.com/Cloud-Schematics/vpc-security-group-rules-module"
  security_group_id    = ibm_is_vpc.vpc.default_security_group
  security_group_rules = var.default_security_group_rules
}

##############################################################################


##############################################################################
# Address Prefixes
##############################################################################

module "address_prefixes" {
  source           = "github.com/Cloud-Schematics/vpc-address-prefix-module"
  prefix           = var.prefix
  region           = var.region
  vpc_id           = ibm_is_vpc.vpc.id
  address_prefixes = var.address_prefixes
}

##############################################################################

##############################################################################
# Network ACLs
##############################################################################

module "network_acls" {
  source       = "github.com/Cloud-Schematics/vpc-network-acl-module"
  prefix       = var.prefix
  vpc_id       = ibm_is_vpc.vpc.id
  network_cidr = var.network_cidr
  network_acls = [
    # Add resource group ID to network ACL objects
    for network_acl in var.network_acls :
    merge(network_acl, { resource_group_id : var.resource_group_id })
  ]
}

##############################################################################

##############################################################################
# Public Gateways
##############################################################################

module "public_gateways" {
  source            = "github.com/Cloud-Schematics/vpc-public-gateway-module"
  prefix            = var.prefix
  vpc_id            = ibm_is_vpc.vpc.id
  region            = var.region
  resource_group_id = var.resource_group_id
  public_gateways   = var.use_public_gateways
}

##############################################################################

##############################################################################
# Subnets
##############################################################################

module "subnets" {
  source                      = "github.com/Cloud-Schematics/vpc-subnet-module"
  prefix                      = var.prefix
  region                      = var.region
  resource_group_id           = var.resource_group_id
  tags                        = var.tags
  vpc_id                      = ibm_is_vpc.vpc.id
  use_manual_address_prefixes = var.use_manual_address_prefixes
  network_acls                = module.network_acls.acls
  public_gateways             = module.public_gateways.gateways
  subnets                     = var.subnets
  depends_on                  = [module.address_prefixes] # Force dependecy on address prefixes to prevent creation errors
}

##############################################################################

##############################################################################
# Security Groups
##############################################################################

module "security_groups" {
  source            = "github.com/Cloud-Schematics/vpc-security-group-module"
  prefix            = var.prefix
  resource_group_id = var.resource_group_id
  tags              = var.tags
  vpc_id            = ibm_is_vpc.vpc.id
  security_groups   = var.security_groups
}

##############################################################################

##############################################################################
# Get Subnet For VPN Gateway
##############################################################################

module "gateway_subnets" {
  source           = "./get_subnets"
  subnet_zone_list = module.subnets.subnet_zone_list
  regex            = var.vpn_gateway.subnet_name
}

##############################################################################

##############################################################################
# VPN Gateway
##############################################################################

module "vpn_gateway" {
  source            = "github.com/Cloud-Schematics/vpc-vpn-gateway-module"
  prefix            = var.prefix
  resource_group_id = var.resource_group_id
  tags              = var.tags
  vpc_id            = ibm_is_vpc.vpc.id
  subnet_id         = lookup(var.vpn_gateway, "use_vpn_gateway", null) == true ? module.gateway_subnets.subnets[0].id : null
  vpn_gateway       = var.vpn_gateway
}

##############################################################################