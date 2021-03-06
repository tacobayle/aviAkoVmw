data "vsphere_datacenter" "dc" {
  name = var.dc
}

data "vsphere_compute_cluster" "compute_cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "networkMgt" {
  name = var.networkMgt
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "networkAviMgt" {
  name = var.avi_cloud["network"]
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "networkBackend" {
  name = var.backend["network"]
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "networkClient" {
  name = var.client["network"]
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_folder" "folder" {
  path          = var.folder
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc.id
}

#resource "vsphere_tag_category" "ansible_group_backend" {
#  name = "ansible_group_backend"
#  cardinality = "SINGLE"
#  associable_types = [
#    "VirtualMachine",
#  ]
#}

resource "vsphere_tag_category" "ansible_group_master" {
  name = "ansible_group_master"
  cardinality = "SINGLE"
  associable_types = [
    "VirtualMachine",
  ]
}

resource "vsphere_tag_category" "ansible_group_worker" {
  name = "ansible_group_worker"
  cardinality = "SINGLE"
  associable_types = [
    "VirtualMachine",
  ]
}

#resource "vsphere_tag_category" "ansible_group_client" {
#  name = "ansible_group_client"
#  cardinality = "SINGLE"
#  associable_types = [
#    "VirtualMachine",
#  ]
#}

resource "vsphere_tag_category" "ansible_group_controller" {
  name = "ansible_group_controller"
  cardinality = "SINGLE"
  associable_types = [
    "VirtualMachine",
  ]
}

#resource "vsphere_tag_category" "ansible_group_jump" {
#  name = "ansible_group_jump"
#  cardinality = "SINGLE"
#  associable_types = [
#    "VirtualMachine",
#  ]
#}

#resource "vsphere_tag_category" "ansible_group_mysql" {
#  name = "ansible_group_mysql"
#  cardinality = "SINGLE"
#  associable_types = [
#    "VirtualMachine",
#  ]
#}

#resource "vsphere_tag_category" "ansible_group_opencart" {
#  name = "ansible_group_opencart"
#  cardinality = "SINGLE"
#  associable_types = [
#    "VirtualMachine",
#  ]
#}
