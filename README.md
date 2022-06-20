# IBM Cloud Solution Engineering Multizone VPC Network

Create VPC network infrastructure with a VPC, subnets, public gateways, network acls, security groups, and an optional VPN gateway.

---

## Table of Contents

1. [VPC](#vpc)
    - [Optional VPC Variables](#optional-vpc-variables)
    - [Default VPC Security Group](#default-vpc-security-group)
2. [Address Prefixes](#address-prefixes)
3. [Network ACLs](#network-acls)
4. [Public Gateways](#public-gateways)
4. [Subnets](#subnets)
5. [Security Groups](#security-groups)
6. [VPN Gateway](#vpn-gateway)
7. [Template Variables]()

---

## VPC

This template creates a single VPC in a resource group.

### Optional VPC Variables

Name                        | Type   | Description                                                                                    | Sensitive | Default
--------------------------- | ------ | ---------------------------------------------------------------------------------------------- | --------- | -------
classic_access              | bool   | OPTIONAL - Classic Access to the VPC                                                           |           | false
use_manual_address_prefixes | bool   | OPTIONAL - Use manual address prefixes for VPC                                                 |           | false
default_network_acl_name    | string | OPTIONAL - Name of the Default ACL. If null, a name will be automatically genetated            |           | null
default_security_group_name | string | OPTIONAL - Name of the Default Security Group. If null, a name will be automatically genetated |           | null
default_routing_table_name  | string | OPTIONAL - Name of the Default Routing Table. If null, a name will be automatically genetated  |           | null

### Default VPC Security Group

Using the [default_security_group_rules](./variables.tf#L330) users can add additional rules to the default VPC security group.

Default VPC Security Group rules are created with the [VPC Security Group Rules Module](https://github.com/Cloud-Schematics/vpc-security-group-rules-module).

### Additional Resources

- [Getting started with VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-getting-started)

---

## Address Prefixes

If you are manually assigning address prefixes at the VPC level, you can specify prefixes to be created using the [address_prefixes variable](./variables.tf#L89). VPCs can have a maximum of 15 unique address prefixes.

```terraform
variable "address_prefixes" {
  description = "OPTIONAL - IP range that will be defined for the VPC for a specified location. Use only with manual address prefixes."
  type = object({
    zone-1 = optional(list(string))
    zone-2 = optional(list(string))
    zone-3 = optional(list(string))
  })
  default = {
    zone-1 = null
    zone-2 = null
    zone-3 = null
  }
  ...
}
```

Address prefixes are created with the [VPC Address Prefixes Module](https://github.com/Cloud-Schematics/vpc-address-prefix-module) for address prefix creation.

---

## Network ACLs

This template can create any number of Network ACLs within the VPC in the VPC Resource Group. Network ACLs can be created using the [network_acls variable](./variables.tf#L114).

```terraform
  type = list(
    object({
      name              = string                 # Name of the ACL. The value of `var.prefix` will be prepended to this name
      add_cluster_rules = optional(bool)         # Dynamically create cluster allow rules
      resource_group_id = optional(string)       # ID of the resource group where the ACL will be created
      tags              = optional(list(string)) # List of tags for the ACL
      rules = list(
        object({
          name        = string # Rule Name
          action      = string # Can be `allow` or `deny`
          destination = string # CIDR for traffic destination
          direction   = string # Can be `inbound` or `outbound`
          source      = string # CIDR for traffic source
          # Any one of the following blocks can be used to create a TCP, UDP, or ICMP rule
          # to allow all kinds of traffic, use no blocks
          tcp = optional(
            object({
              port_max        = optional(number)
              port_min        = optional(number)
              source_port_max = optional(number)
              source_port_min = optional(number)
            })
          )
          udp = optional(
            object({
              port_max        = optional(number)
              port_min        = optional(number)
              source_port_max = optional(number)
              source_port_min = optional(number)
            })
          )
          icmp = optional(
            object({
              type = optional(number)
              code = optional(number)
            })
          )
        })
      )
    })
  )
```

This template uses the [VPC Network ACLs Module](https://github.com/Cloud-Schematics/vpc-network-acl-module) to create Network ACLs.

### Additional Resources

- [IBM Cloud VPC Network Access Control Lists Documentation](https://cloud.ibm.com/docs/vpc?topic=vpc-using-acls)

--- 

## Public Gateways

This template can provision a gateway in any number of zones within the same VPC. Public Gateways are defined using the [use_public_gateways variable](./variables.tf#L241).

```terraform
variable "public_gateways" {
  description = "Create a public gateway in any of the three zones with `true`."
  type = object({
    zone-1 = optional(bool)
    zone-2 = optional(bool)
    zone-3 = optional(bool)
  })
  default = {
    zone-1 = true
    zone-2 = true
    zone-3 = true
  }
}
```


This template uses the [VPC Public Gateway Module](https://github.com/Cloud-Schematics/vpc-public-gateway-module) to create Public Gateways.

### Additional Resources

- [About VPC Networking](https://cloud.ibm.com/docs/vpc?topic=vpc-about-networking-for-vpc)

---

## Subnets

This template can create any number of subnets across any number of zones within the VPC. Subnets will be added to the VPC resource group. Subnet creation is handled by the [subnets variable](./variables.tf#L267). If you are not using manual address prefixes, an address prefix for the subnet CIDR block will be created on the VPC.

```terraform
  type = object({
    zone-1 = list(object({
      name           = string         # Name of the subnet
      cidr           = string         # CIDR block
      public_gateway = optional(bool) # Use public gateway, will only be attached if a gateway is provisioned in the same zone as the subnet
      acl_name       = string         # Name of network ACL to use. Will only be attached if name is found in var.network_acls
    }))
    zone-2 = list(object({
      name           = string
      cidr           = string
      public_gateway = optional(bool)
      acl_name       = string
    }))
    zone-3 = list(object({
      name           = string
      cidr           = string
      public_gateway = optional(bool)
      acl_name       = string
    }))
  })
```

This template uses the [VPC Subnet Module](https://github.com/Cloud-Schematics/vpc-subnet-module) to create Subnets and address prefixes.

### Additional Resources

- [About VPC Networking](https://cloud.ibm.com/docs/vpc?topic=vpc-about-networking-for-vpc)

---

## Security Groups

Any number of additional security groups and rules can be created using the [security_groups variable](./variables.tf#L414). These security groups will be created in the VPC resource group.

```terraform
variable "security_groups" {
  description = "Security groups for VPC"
  type = list(
    object({
      name = string # Name
      rules = list( # List of rules
        object({
          name      = string # name of rule
          direction = string # can be inbound or outbound
          remote    = string # ip address to allow traffic from
          ##############################################################################
          # One or none of these optional blocks can be added
          # > if none are added, rule will be for any type of traffic
          ##############################################################################
          tcp = optional(
            object({
              port_max = number
              port_min = number
            })
          )
          udp = optional(
            object({
              port_max = number
              port_min = number
            })
          )
          icmp = optional(
            object({
              type = number
              code = number
            })
          )
        })
      )
    })
  )
  ...
}
```

This template uses the [VPC Security Group Module](https://github.com/Cloud-Schematics/vpc-security-group-module) to create security groups and security group rules.

### Additional Resources

- [Using VPC Security Groups](https://cloud.ibm.com/docs/vpc?topic=vpc-using-security-groups)

--- 

## VPN Gateway

This template can create a single VPN gateway in a subnet within the VPC, and any number of connections for the gateway. VPN Gateway and Connections can be managed with the [vpn_gateway variable](./variables.tf#L517).

```terraform
variable "vpn_gateway" {
  description = "VPN Gateways to create."
  type = object({
    use_vpn_gateway = bool             # create vpn gateway
    name            = optional(string) # gateway name
    subnet_name     = optional(string) # Do not include prefix, use same name as in `var.subnets`
    mode            = optional(string) # Can be `route` or `policy`. Default is `route`
    connections = list(
      object({
        peer_address   = string                 # The IP address of the peer VPN gateway.
        preshared_key  = string                 # The preshared key.
        local_cidrs    = optional(list(string)) # List of local CIDRs for this resource.
        peer_cidrs     = optional(list(string)) # List of peer CIDRs for this resource.
        admin_state_up = optional(bool)         # The VPN gateway connection status. Default value is false. If set to false, the VPN gateway connection is shut down.
      })
    )
  })
  ...
}
```

VPN Gateway and VPN Gateway connections are created using the [VPN Gateway Module](https://github.com/Cloud-Schematics/vpc-vpn-gateway-module).

### Additional Resources

- [VPNs for VPC](https://cloud.ibm.com/docs/vpc?topic=vpc-vpn-overview)

---

## Template Variables

Name                         | Description
---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
ibmcloud_api_key             | The IBM Cloud platform API key needed to deploy IAM enabled resources.
resource_group               | Name of existing resource group where all infrastructure will be provisioned
region                       | The region to which to deploy the VPC
prefix                       | The prefix that you would like to append to your resources
tags                         | List of Tags for the resource created
network_cidr                 | Network CIDR for the VPC. This is used to manage network ACL rules for cluster provisioning.
vpc_name                     | Name for vpc. If left null, one will be generated using the prefix for this module.
classic_access               | OPTIONAL - Classic Access to the VPC
use_manual_address_prefixes  | OPTIONAL - Use manual address prefixes for VPC
default_network_acl_name     | OPTIONAL - Name of the Default ACL. If null, a name will be automatically genetated
default_security_group_name  | OPTIONAL - Name of the Default Security Group. If null, a name will be automatically genetated
default_routing_table_name   | OPTIONAL - Name of the Default Routing Table. If null, a name will be automatically genetated
address_prefixes             | OPTIONAL - IP range that will be defined for the VPC for a specified location. Use only with manual address prefixes.
network_acls                 | List of ACLs to create. Rules can be automatically created to allow inbound and outbound traffic from a VPC tier by adding the name of that tier to the `network_connections` list. Rules automatically generated by these network connections will be added at the beginning of a list, and will be web-tierlied to traffic first. At least one rule must be provided for each ACL.
use_public_gateways          | Create a public gateway in any of the three zones with `true`.
subnets                      | List of subnets for the vpc. For each item in each array, a subnet will be created. Items can be either CIDR blocks or total ipv4 addressess. Public gateways will be enabled only in zones where a gateway has been created
default_security_group_rules | A list of security group rules to be added to the default vpc security group
security_groups              | Security groups for VPC
vpn_gateway                  | VPN Gateways to create.