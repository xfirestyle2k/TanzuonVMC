provider "vmc" {
  refresh_token = var.API_token
  org_id = var.org_id
}
# Empty data source defined in order to store the org display name and name in terraform state
data "vmc_org" "my_org" {
}

data "vmc_connected_accounts" "my_accounts" {
  account_number = var.aws_account_number
}

data "vmc_customer_subnets" "my_subnets" {
  connected_account_id = data.vmc_connected_accounts.my_accounts.id
  region               = replace(upper(var.sddc_region), "-", "_")
}

resource "vmc_sddc" "sddc_2" {
  sddc_name           = var.sddc_name
  vpc_cidr            = var.sddc_mgmt_subnet
  num_host            = var.sddc_num_hosts
  provider_type       = var.provider_type
  region              = var.sddc_region
  vxlan_subnet        = var.sddc_client_net
  delay_account_link  = true
  skip_creating_vxlan = false
  sso_domain          = "vmc.local"
  sddc_type           = var.sddc_type
  deployment_type     = var.deployment_type
  size                = var.size
  host_instance_type  = var.host_instance_type

  account_link_sddc_config {
    customer_subnet_ids  = [data.vmc_customer_subnets.my_subnets.ids[0]]
    connected_account_id = data.vmc_connected_accounts.my_accounts.id
  }

  microsoft_licensing_config {
    mssql_licensing = "DISABLED"
    windows_licensing = "DISABLED"
  }

  timeouts {
    create = "300m"
    update = "300m"
    delete = "180m"
  }
}

#########################################################
######## Find a way to get host after deployment ########
#########################################################


provider "nsxt" {
    host                 = var.host
    vmc_token            = var.API_token
    allow_unverified_ssl = true
    enforcement_point    = "vmc-enforcementpoint"
 }

###################### creating Network Segments ######################
###################### can be outcommented "/* */" or edited ######################

data "nsxt_policy_transport_zone" "TZ" {
  display_name = "vmc-overlay-tz"
}

resource "nsxt_policy_segment" "Inbound-Network" {
  display_name        = "Horizon_MGMT"
  description         = "Horizon_MGMT Segment provisioned by Terraform"
  connectivity_path   = "/infra/tier-1s/cgw"
  transport_zone_path = data.nsxt_policy_transport_zone.TZ.path
  subnet {
    cidr              = "192.168.2.1/24"
    dhcp_ranges       = ["192.168.2.2-192.168.2.254"]
  }
}

resource "nsxt_policy_segment" "Outbound-Network" {
  display_name        = "Horizon_UAG_external"
  description         = "Horizon_UAG_external Segment provisioned by Terraform"
  connectivity_path   = "/infra/tier-1s/cgw"
  transport_zone_path = data.nsxt_policy_transport_zone.TZ.path
  subnet {
    cidr              = "192.168.3.1/24"
    dhcp_ranges       = ["192.168.3.2-192.168.3.254"]
  }
}

resource "nsxt_policy_segment" "Tanzu-Management" {
  display_name        = "Horizon_UAG_external"
  description         = "Horizon_UAG_external Segment provisioned by Terraform"
  connectivity_path   = "/infra/tier-1s/cgw"
  transport_zone_path = data.nsxt_policy_transport_zone.TZ.path
  subnet {
    cidr              = "192.168.10.1/24"
    dhcp_ranges       = ["192.168.10.2-192.168.10.254"]
  }
}

provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

############################################################################################
######## Find a way to get cloudadmin, password and vshpere server after deployment ########
############################################################################################

data "vsphere_datacenter" "dc" {
  name = SDDC-Datacenter
}
data "vsphere_compute_cluster" "cluster" {
  name          = Cluster-1
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_datastore" "datastore" {
  name          = WorkloadDatastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = Compute-ResourcePool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = sddc-cgw-network-1
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_content_library" "Tanzu_Library" {
  name            = "Tanzu-Library"
  storage_backing = [data.vsphere_datastore.datastore.id]
  description     = "Tanzu-Library by Terraform"
  subscription {
    subscription_url      = "https://wp-content.vmware.com/v2/latest/lib.json"
    authentication_method = "NONE"
    automatic_sync        = false
    on_demand             = false
  }
}

data "vsphere_content_library_item" "library_item_photon" {
  depends_on = [time_sleep.wait_1200_seconds]
  name       = "ob-18186591-photon-3-k8s-v1.20.7---vmware.1-tkg.1.7fb9067"
  library_id = vsphere_content_library.Tanzu_Library.id
  type       = "OVA"
}


resource "vsphere_virtual_machine" "Tanzu-temp" {
  name             = "Tanzu-temp"
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = "Workloads"

  num_cpus = 4
  memory   = 4096
  guest_id = "other3xLinux64Guest"

  network_interface {
    network_id = data.vsphere_network.network.id
  }
  disk {
    label            = "disk0"
    size             = 50
    thin_provisioned = true
  }
  clone {
    template_uuid = data.vsphere_content_library_item.library_item_photon.id
    customize {
      linux_options {
        host_name = var.VMName
        domain    = var.VMDomain
      }
      network_interface {}
    }
  }
}

## sleep timer for the sync to be completed ##

resource "time_sleep" "wait_1200_seconds" {
  depends_on = [vsphere_content_library.subscribedlibrary_terraform]
  create_duration = "1200s"
}