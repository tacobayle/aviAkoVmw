#resource "vsphere_tag" "ansible_group_jump" {
#  name             = "jump"
#  category_id      = vsphere_tag_category.ansible_group_jump.id
#}


data "template_file" "jumpbox_userdata" {
  template = file("${path.module}/userdata/jump.userdata")
  vars = {
    password      = var.jump["password"]
    pubkey        = file(var.jump["public_key_path"])
    avisdkVersion = var.jump["avisdkVersion"]
    ansibleVersion = var.ansible["version"]
    vsphere_user  = var.vsphere_user
    vsphere_password = var.vsphere_password
    vsphere_server = var.vsphere_server
    username = var.jump["username"]
    privateKey = var.jump["private_key_path"]
  }
}
#
data "vsphere_virtual_machine" "jump" {
  name          = var.jump["template_name"]
  datacenter_id = data.vsphere_datacenter.dc.id
}
#
resource "vsphere_virtual_machine" "jump" {
  name             = var.jump["name"]
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = vsphere_folder.folder.path
  network_interface {
                      network_id = data.vsphere_network.networkMgt.id
  }

  num_cpus = var.jump["cpu"]
  memory = var.jump["memory"]
  wait_for_guest_net_timeout = var.jump["wait_for_guest_net_timeout"]
  guest_id = data.vsphere_virtual_machine.jump.guest_id
  scsi_type = data.vsphere_virtual_machine.jump.scsi_type
  scsi_bus_sharing = data.vsphere_virtual_machine.jump.scsi_bus_sharing
  scsi_controller_count = data.vsphere_virtual_machine.jump.scsi_controller_scan_count

  disk {
    size             = var.jump["disk"]
    label            = "jump.lab_vmdk"
    eagerly_scrub    = data.vsphere_virtual_machine.jump.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.jump.disks.0.thin_provisioned
  }

  cdrom {
    client_device = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.jump.id
  }

#  tags = [
#        vsphere_tag.ansible_group_jump.id,
#  ]

  vapp {
    properties = {
     hostname    = "jump"
     password    = var.jump["password"]
     public-keys = file(var.jump["public_key_path"])
     user-data   = base64encode(data.template_file.jumpbox_userdata.rendered)
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

  provisioner "file" {
  source      = var.jump["private_key_path"]
  destination = "~/.ssh/${basename(var.jump["private_key_path"])}"
  }

  provisioner "file" {
  source      = var.ansible["directory"]
  destination = "~/ansible"
  }

  provisioner "file" {
  content      = <<EOF
{"deploymentUrls": ${jsonencode(var.deploymentUrls)}, "nfsShares": ${jsonencode(var.nfsShares)}, "kubernetesMasterIpCidr": "${vsphere_virtual_machine.master[0].guest_ip_addresses[2]}${var.kubernetes["networkPrefix"]}", "kubernetes": ${jsonencode(var.kubernetes)}}
EOF
  destination = "~/ansible/vars/fromTerraformForKubernetes.json"
  }

  provisioner "file" {
  content      = <<EOF
---

controller:
  environment: ${var.controller["environment"]}
  username: ${var.avi_user}
  version: ${split("-", var.controller["version"])[0]}
  password: ${var.avi_password}
  floatingIp: ${var.controller["floatingIp"]}
  count: ${var.controller["count"]}

controllerPrivateIps:
  ${yamlencode(vsphere_virtual_machine.controller.*.default_ip_address)}

avi_systemconfiguration:
  global_tenant_config:
    se_in_provider_context: false
    tenant_access_to_provider_se: true
    tenant_vrf: false
  welcome_workflow_complete: true
  ntp_configuration:
    ntp_servers:
      - server:
          type: V4
          addr: ${var.controller["ntpMain"]}
  dns_configuration:
    search_domain: ''
    server_list:
      - type: V4
        addr: ${var.controller["dnsMain"]}
  email_configuration:
    from_email: test@avicontroller.net
    smtp_type: SMTP_LOCAL_HOST

vmw:
  name: &cloud0 cloudVmw # don't change it
  network: ${var.avi_cloud["network"]}
  networkDhcpEnabled: ${var.avi_cloud["networkDhcpEnabled"]}
  networkExcludeDiscoveredSubnets: ${var.avi_cloud["networkExcludeDiscoveredSubnets"]}
  networkVcenterDvs: ${var.avi_cloud["networkVcenterDvs"]}
  dhcp_enabled: ${var.avi_cloud["dhcp_enabled"]}
  vcenter_configuration:
    username: ${var.vsphere_user}
    password: ${var.vsphere_password}
    vcenter_url: ${var.vsphere_server}
    privilege: WRITE_ACCESS
    datacenter: ${var.dc}
    management_network: "/api/vimgrnwruntime/?name=${var.avi_cloud["network"]}"

serviceEngineGroup:
  - name: &segroup0 Default-Group
    cloud_ref: *cloud0
    ha_mode: HA_MODE_SHARED
    min_scaleout_per_vs: 2
    buffer_se: 1
    extra_shared_config_memory: 0
    vcenter_folder: ${var.folder}
    vcpus_per_se: 2
    memory_per_se: 4096
    disk_per_se: 25
    realtime_se_metrics:
      enabled: true
      duration: 0
  - name: &segroup1 seGroupCpuAutoScale
    cloud_ref: *cloud0
    ha_mode: HA_MODE_SHARED
    min_scaleout_per_vs: 1
    buffer_se: 2
    extra_shared_config_memory: 0
    vcenter_folder: ${var.folder}
    vcpus_per_se: 1
    memory_per_se: 2048
    disk_per_se: 25
    auto_rebalance: true
    auto_rebalance_interval: 30
    auto_rebalance_criteria:
    - SE_AUTO_REBALANCE_CPU
    realtime_se_metrics:
      enabled: true
      duration: 0
  - name: &segroup2 seGroupGslb
    cloud_ref: *cloud0
    ha_mode: HA_MODE_SHARED
    min_scaleout_per_vs: 1
    buffer_se: 0
    extra_shared_config_memory: 2000
    vcenter_folder: ${var.folder}
    vcpus_per_se: 2
    memory_per_se: 8192
    disk_per_se: 25
    realtime_se_metrics:
      enabled: true
      duration: 0
  - name: &segroup3 seGroupAko
    cloud_ref: *cloud0
    ha_mode: HA_MODE_SHARED
    min_scaleout_per_vs: 2
    buffer_se: 1
    extra_shared_config_memory: 0
    vcenter_folder: ${var.folder}
    vcpus_per_se: 2
    memory_per_se: 4096
    disk_per_se: 25
    realtime_se_metrics:
      enabled: true
      duration: 0
  - name: &segroup4 seGroupAmko
    cloud_ref: *cloud0
    ha_mode: HA_MODE_SHARED
    min_scaleout_per_vs: 1
    buffer_se: 0
    extra_shared_config_memory: 2000
    vcenter_folder: ${var.folder}
    vcpus_per_se: 2
    memory_per_se: 8192
    disk_per_se: 25
    realtime_se_metrics:
      enabled: true
      duration: 0

domain:
  name: ${var.domain["name"]}

avi_network_vip:
  name: ${var.avi_network_vip["name"]}
  dhcp_enabled: ${var.avi_network_vip["dhcp_enabled"]}
  exclude_discovered_subnets: ${var.avi_network_vip["exclude_discovered_subnets"]}
  vcenter_dvs: ${var.avi_network_vip["vcenter_dvs"]}
  subnet:
    - prefix:
        mask: "${element(split("/", var.avi_network_vip["subnet"]),1)}"
        ip_addr:
          type: "${var.avi_network_vip["type"]}"
          addr: "${element(split("/", var.avi_network_vip["subnet"]),0)}"
      static_ranges:
        - begin:
            type: "${var.avi_network_vip["type"]}"
            addr: "${var.avi_network_vip["begin"]}"
          end:
            type: "${var.avi_network_vip["type"]}"
            addr: "${var.avi_network_vip["end"]}"

avi_network_backend:
  name: ${var.backend["network"]}
  dhcp_enabled: ${var.avi_network_backend["dhcp_enabled"]}
  exclude_discovered_subnets: ${var.avi_network_backend["exclude_discovered_subnets"]}
  vcenter_dvs: ${var.avi_network_backend["vcenter_dvs"]}
  subnet:
    - prefix:
        mask: "${element(split("/", var.avi_network_backend["subnet"]),1)}"
        ip_addr:
          type: "${var.avi_network_backend["type"]}"
          addr: "${element(split("/", var.avi_network_backend["subnet"]),0)}"

EOF
  destination = "~/ansible/vars/fromTerraform.yml"
  }

  provisioner "remote-exec" {
    inline      = [
      "cat ~/ansible/vars/fromTerraformForKubernetes.json",
      "cat ~/ansible/vars/fromTerraform.yml",
      "chmod 600 ~/.ssh/${basename(var.jump["private_key_path"])}",
      "cd ~/ansible ; git clone ${var.ansible["k8sInstallUrl"]} --branch ${var.ansible["k8sInstallTag"]} ; ansible-playbook -i /opt/ansible/inventory/inventory.vmware.yml ansibleK8sInstall/main.yml --extra-vars @vars/fromTerraformForKubernetes.json",
      "cd ~/ansible ; git clone ${var.ansible["aviConfigureUrl"]} --branch ${var.ansible["aviConfigureTag"]} ; ansible-playbook -i /opt/ansible/inventory/inventory.vmware.yml aviConfigure/local.yml --extra-vars @vars/fromTerraform.yml",
    ]
  }

}
