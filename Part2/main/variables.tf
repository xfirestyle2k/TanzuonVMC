
variable "vmc_token"    {}  # in env variables
variable "host"         {}  # in phase1.tfstate

/*================
Subnets IP ranges
=================*/
variable "VMC_subnets" {
  default = {
    TKG_net             = "192.168.2.0/24"
    TKG_net_gw          = "192.168.2.1/24"
    TKG_net_dhcp        = "192.168.2.3-192.168.2.254"
  }
}



