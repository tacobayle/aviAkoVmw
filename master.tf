

resource "vsphere_tag" "ansible_group_master" {
  name             = "master"
  category_id      = vsphere_tag_category.ansible_group_master.id
}


data "template_file" "master_userdata" {
  count = var.master["count"]
  template = file("${path.module}/userdata/master.userdata")
  vars = {
    password     = var.master["password"]
    pubkey       = file(var.jump["public_key_path"])
  }
}
#
data "vsphere_virtual_machine" "master" {
  name          = var.master["template_name"]
  datacenter_id = data.vsphere_datacenter.dc.id
}
#
resource "vsphere_virtual_machine" "master" {
  count = var.master["count"]
  name             = "master-${count.index}"
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = vsphere_folder.folder.path

  network_interface {
                      network_id = data.vsphere_network.networkMgt.id
  }

  network_interface {
                      network_id = data.vsphere_network.networkBackend.id
  }


  num_cpus = var.master["cpu"]
  memory = var.master["memory"]
  #wait_for_guest_net_timeout = var.master["wait_for_guest_net_timeout"]
  wait_for_guest_net_routable = var.master["wait_for_guest_net_routable"]
  guest_id = data.vsphere_virtual_machine.master.guest_id
  scsi_type = data.vsphere_virtual_machine.master.scsi_type
  scsi_bus_sharing = data.vsphere_virtual_machine.master.scsi_bus_sharing
  scsi_controller_count = data.vsphere_virtual_machine.master.scsi_controller_scan_count

  disk {
    size             = var.master["disk"]
    label            = "master-${count.index}.lab_vmdk"
    eagerly_scrub    = data.vsphere_virtual_machine.master.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.master.disks.0.thin_provisioned
  }

  cdrom {
    client_device = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.master.id
  }

  tags = [
        vsphere_tag.ansible_group_master.id,
  ]

    #customize {

    #  network_interface {
    #    ipv4_address = "10.0.0.10"
    #    ipv4_netmask = 24
    #  }
    #  ipv4_gateway = "10.0.0.1"
    #  dns_server_list = "8.8.8.8"
    #}

  vapp {
    properties = {
     hostname    = "master-${count.index}"
     password    = var.master["password"]
     public-keys = file(var.jump["public_key_path"])
     user-data   = base64encode(data.template_file.master_userdata[count.index].rendered)
   }
 }

  connection {
    host        = self.default_ip_address
    type        = "ssh"
    agent       = false
    user        = "ubuntu"
    private_key = file(var.jump["private_key_path"])
    }

  provisioner "remote-exec" {
    inline      = [
      "while [ ! -f /tmp/cloudInitDone.log ]; do sleep 1; done"
    ]
  }
}