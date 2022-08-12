module "local_execution" {
  source  = "../generic_modules/local_exec"
  enabled = var.pre_deployment
}

# This locals entry is used to store the IP addresses of all the machines.
# Autogenerated addresses example based in 192.168.135.0/24
# Iscsi server: 192.168.135.4
# Monitoring: 192.168.135.5
# Hana ips: 192.168.135.10, 192.168.135.11
# Hana cluster vip: 192.168.135.12
# Hana cluster vip secondary: 192.168.135.13
# Hana majority maker ip: 192.168.135.9
# DRBD ips: 192.168.135.20, 192.168.135.21
# DRBD cluster vip: 192.168.135.22
# Netweaver ips: 192.168.135.30, 192.168.135.31, 192.168.135.32, 192.168.135.33
# Netweaver virtual ips: 192.168.135.34, 192.168.135.35, 192.168.135.36, 19.168.135.37
# If the addresses are provided by the user they will always have preference
locals {
  iscsi_ip          = var.iscsi_srv_ip != "" ? var.iscsi_srv_ip : cidrhost(local.iprange, 4)
  monitoring_srv_ip = var.monitoring_srv_ip != "" ? var.monitoring_srv_ip : cidrhost(local.iprange, 5)

  hana_ip_start              = 10
  hana_ips                   = length(var.hana_ips) != 0 ? var.hana_ips : [for ip_index in range(local.hana_ip_start, local.hana_ip_start + var.hana_count) : cidrhost(local.iprange, ip_index)]
  hana_cluster_vip           = var.hana_cluster_vip != "" ? var.hana_cluster_vip : cidrhost(local.iprange, local.hana_ip_start + var.hana_count)
  hana_cluster_vip_secondary = var.hana_cluster_vip_secondary != "" ? var.hana_cluster_vip_secondary : cidrhost(local.iprange, local.hana_ip_start + var.hana_count + 1)
  hana_majority_maker_ip     = var.hana_majority_maker_ip != "" ? var.hana_majority_maker_ip : cidrhost(local.iprange, local.hana_ip_start - 1)

  # 2 is hardcoded for drbd because we always deploy 2 machines
  drbd_ip_start    = 20
  drbd_ips         = length(var.drbd_ips) != 0 ? var.drbd_ips : [for ip_index in range(local.drbd_ip_start, local.drbd_ip_start + 2) : cidrhost(local.iprange, ip_index)]
  drbd_cluster_vip = var.drbd_cluster_vip != "" ? var.drbd_cluster_vip : cidrhost(local.iprange, local.drbd_ip_start + 2)

  netweaver_xscs_server_count = var.netweaver_enabled ? (var.netweaver_ha_enabled ? 2 : 1) : 0
  netweaver_count             = var.netweaver_enabled ? local.netweaver_xscs_server_count + var.netweaver_app_server_count : 0
  netweaver_virtual_ips_count = var.netweaver_ha_enabled ? max(local.netweaver_count, 3) : max(local.netweaver_count, 2) # We need at least 2 virtual ips, if ASCS and PAS are in the same machine

  netweaver_ip_start    = 30
  netweaver_ips         = length(var.netweaver_ips) != 0 ? var.netweaver_ips : [for ip_index in range(local.netweaver_ip_start, local.netweaver_ip_start + local.netweaver_count) : cidrhost(local.iprange, ip_index)]
  netweaver_virtual_ips = length(var.netweaver_virtual_ips) != 0 ? var.netweaver_virtual_ips : [for ip_index in range(local.netweaver_ip_start, local.netweaver_ip_start + local.netweaver_virtual_ips_count) : cidrhost(local.iprange, ip_index + local.netweaver_virtual_ips_count)]

  # Check if iscsi server has to be created
  use_sbd       = var.hana_cluster_fencing_mechanism == "sbd" || var.drbd_cluster_fencing_mechanism == "sbd" || var.netweaver_cluster_fencing_mechanism == "sbd"
  iscsi_enabled = var.sbd_storage_type == "iscsi" && ((var.hana_count > 1 && var.hana_ha_enabled) || var.drbd_enabled || (local.netweaver_count > 1 && var.netweaver_ha_enabled)) && local.use_sbd ? true : false

  # Netweaver password checking
  # If Netweaver is not enabled, a dummy password is passed to pass the variable validation and not require
  # a password in this case
  # Otherwise, the validation will fail unless a correct password is provided
  netweaver_master_password = var.netweaver_enabled ? var.netweaver_master_password : "DummyPassword1234"

  # check if scale-out is enabled and if "data/log" are local disks (not shared)
  hana_basepath_shared = var.hana_scale_out_enabled && contains(split("#", lookup(var.hana_data_disks_configuration, "names", "")), "data") && contains(split("#", lookup(var.hana_data_disks_configuration, "names", "")), "log") ? false : true

  # there is one block_device less if sbd+iscsi is used (no shared volume)
  hana_block_devices = local.iscsi_enabled ? "/dev/vdb,/dev/vdc,/dev/vdd,/dev/vde,/dev/vdf,/dev/vdg,/dev/vdh,/dev/vdi,/dev/vdj,/dev/vdk,/dev/vdl,/dev/vdm,/dev/vdn,/dev/vdo,/dev/vdp,/dev/vdq,/dev/vdr,/dev/vds,/dev/vdt,/dev/vdu,/dev/vdv,/dev/vdw,/dev/vdx,/dev/vdy,/dev/vdz" : "/dev/vdc,/dev/vdd,/dev/vde,/dev/vdf,/dev/vdg,/dev/vdh,/dev/vdi,/dev/vdj,/dev/vdk,/dev/vdl,/dev/vdm,/dev/vdn,/dev/vdo,/dev/vdp,/dev/vdq,/dev/vdr,/dev/vds,/dev/vdt,/dev/vdu,/dev/vdv,/dev/vdw,/dev/vdx,/dev/vdy,/dev/vdz"


}

data "template_file" "userdata" {
  template = file("${path.root}/cloud-config.tpl")
  # You can also pass variables here to further customize config.
  # vars = {
  #   name = "value"
  # }
}

resource "libvirt_cloudinit_disk" "userdata" {
  name      = "cloudinit.iso"
  user_data = data.template_file.userdata.rendered
}


module "common_variables" {
  source                              = "../generic_modules/common_variables"
  provider_type                       = "libvirt"
  deployment_name                     = local.deployment_name
  deployment_name_in_hostname         = var.deployment_name_in_hostname
  reg_code                            = var.reg_code
  reg_email                           = var.reg_email
  reg_additional_modules              = var.reg_additional_modules
  ha_sap_deployment_repo              = var.ha_sap_deployment_repo
  additional_packages                 = var.additional_packages
  authorized_keys                     = var.authorized_keys
  authorized_user                     = var.admin_user
  provisioner                         = var.provisioner
  provisioning_log_level              = var.provisioning_log_level
  provisioning_output_colored         = var.provisioning_output_colored
  background                          = var.background
  monitoring_enabled                  = var.monitoring_enabled
  monitoring_srv_ip                   = var.monitoring_enabled ? local.monitoring_srv_ip : ""
  offline_mode                        = var.offline_mode
  cleanup_secrets                     = var.cleanup_secrets
  hana_hwcct                          = var.hwcct
  hana_sid                            = var.hana_sid
  hana_instance_number                = var.hana_instance_number
  hana_cost_optimized_sid             = var.hana_cost_optimized_sid
  hana_cost_optimized_instance_number = var.hana_cost_optimized_instance_number
  hana_master_password                = var.hana_master_password
  hana_cost_optimized_master_password = var.hana_cost_optimized_master_password == "" ? var.hana_master_password : var.hana_cost_optimized_master_password
  hana_primary_site                   = var.hana_primary_site
  hana_secondary_site                 = var.hana_secondary_site
  hana_inst_master                    = var.hana_inst_master
  hana_inst_folder                    = var.hana_inst_folder
  hana_fstype                         = var.hana_fstype
  hana_platform_folder                = var.hana_platform_folder
  hana_sapcar_exe                     = var.hana_sapcar_exe
  hana_archive_file                   = var.hana_archive_file
  hana_extract_dir                    = var.hana_extract_dir
  hana_client_folder                  = var.hana_client_folder
  hana_client_archive_file            = var.hana_client_archive_file
  hana_client_extract_dir             = var.hana_client_extract_dir
  hana_scenario_type                  = var.scenario_type
  hana_cluster_vip_mechanism          = "vip-only"
  hana_cluster_vip                    = local.hana_cluster_vip
  hana_cluster_vip_secondary          = var.hana_active_active ? local.hana_cluster_vip_secondary : ""
  hana_ha_enabled                     = var.hana_ha_enabled
  hana_ignore_min_mem_check           = var.hana_ignore_min_mem_check
  hana_cluster_fencing_mechanism      = var.hana_cluster_fencing_mechanism
  hana_sbd_storage_type               = var.sbd_storage_type
  hana_scale_out_enabled              = var.hana_scale_out_enabled
  hana_scale_out_shared_storage_type  = var.hana_scale_out_shared_storage_type
  hana_scale_out_addhosts             = var.hana_scale_out_addhosts
  hana_scale_out_standby_count        = var.hana_scale_out_standby_count
  hana_basepath_shared                = local.hana_basepath_shared
  netweaver_sid                       = var.netweaver_sid
  netweaver_ascs_instance_number      = var.netweaver_ascs_instance_number
  netweaver_ers_instance_number       = var.netweaver_ers_instance_number
  netweaver_pas_instance_number       = var.netweaver_pas_instance_number
  netweaver_master_password           = local.netweaver_master_password
  netweaver_product_id                = var.netweaver_product_id
  netweaver_inst_folder               = var.netweaver_inst_folder
  netweaver_extract_dir               = var.netweaver_extract_dir
  netweaver_swpm_folder               = var.netweaver_swpm_folder
  netweaver_sapcar_exe                = var.netweaver_sapcar_exe
  netweaver_swpm_sar                  = var.netweaver_swpm_sar
  netweaver_sapexe_folder             = var.netweaver_sapexe_folder
  netweaver_additional_dvds           = var.netweaver_additional_dvds
  netweaver_nfs_share                 = var.drbd_enabled ? "${local.drbd_cluster_vip}:/${var.netweaver_sid}" : var.netweaver_nfs_share
  netweaver_sapmnt_path               = var.netweaver_sapmnt_path
  netweaver_hana_ip                   = var.hana_ha_enabled ? local.hana_cluster_vip : element(local.hana_ips, 0)
  netweaver_hana_sid                  = var.hana_sid
  netweaver_hana_instance_number      = var.hana_instance_number
  netweaver_hana_master_password      = var.hana_master_password
  netweaver_ha_enabled                = var.netweaver_ha_enabled
  netweaver_cluster_vip_mechanism     = "vip-only"
  netweaver_cluster_fencing_mechanism = var.netweaver_cluster_fencing_mechanism
  netweaver_sbd_storage_type          = var.sbd_storage_type
  netweaver_shared_storage_type       = var.netweaver_shared_storage_type
  monitoring_hana_targets             = var.hana_scale_out_enabled ? concat(local.hana_ips, [local.hana_majority_maker_ip]) : local.hana_ips
  monitoring_hana_targets_ha          = var.hana_ha_enabled ? (var.hana_scale_out_enabled ? concat(local.hana_ips, [local.hana_majority_maker_ip]) : local.hana_ips) : []
  monitoring_hana_targets_vip         = var.hana_ha_enabled ? [local.hana_cluster_vip] : [local.hana_ips[0]] # we use the vip for HA scenario and 1st hana machine for non HA to target the active hana instance
  monitoring_drbd_targets             = var.drbd_enabled ? local.drbd_ips : []
  monitoring_drbd_targets_ha          = var.drbd_enabled ? local.drbd_ips : []
  monitoring_drbd_targets_vip         = var.drbd_enabled ? [local.drbd_cluster_vip] : []
  monitoring_netweaver_targets        = var.netweaver_enabled ? local.netweaver_ips : []
  monitoring_netweaver_targets_ha     = var.netweaver_enabled && var.netweaver_ha_enabled ? [local.netweaver_ips[0], local.netweaver_ips[1]] : []
  monitoring_netweaver_targets_vip    = var.netweaver_enabled ? local.netweaver_virtual_ips : []
  drbd_cluster_vip                    = local.drbd_cluster_vip
  drbd_cluster_vip_mechanism          = "vip-only"
  drbd_cluster_fencing_mechanism      = var.drbd_cluster_fencing_mechanism
  drbd_sbd_storage_type               = var.sbd_storage_type
}

module "iscsi_server" {
  source                = "./modules/iscsi_server"
  common_variables      = module.common_variables.configuration
  name                  = var.iscsi_name
  network_domain        = var.iscsi_network_domain == "" ? var.network_domain : var.iscsi_network_domain
  iscsi_count           = local.iscsi_enabled == true ? 1 : 0
  source_image          = var.iscsi_source_image
  volume_name           = var.iscsi_source_image != "" ? "" : (var.iscsi_volume_name != "" ? var.iscsi_volume_name : local.generic_volume_name)
  vcpu                  = var.iscsi_vcpu
  memory                = var.iscsi_memory
  bridge                = var.bridge_device
  storage_pool          = var.storage_pool
  userdata              = libvirt_cloudinit_disk.userdata.id
  isolated_network_id   = local.internal_network_id
  isolated_network_name = local.internal_network_name
  host_ips              = [local.iscsi_ip]
  lun_count             = var.iscsi_lun_count
  iscsi_disk_size       = var.sbd_disk_size
}

module "hana_node" {
  source                        = "./modules/hana_node"
  common_variables              = module.common_variables.configuration
  name                          = var.hana_name
  network_domain                = var.hana_network_domain == "" ? var.network_domain : var.hana_network_domain
  source_image                  = var.hana_source_image
  volume_name                   = var.hana_source_image != "" ? "" : (var.hana_volume_name != "" ? var.hana_volume_name : local.generic_volume_name)
  hana_count                    = var.hana_count
  vcpu                          = var.hana_node_vcpu
  memory                        = var.hana_node_memory
  bridge                        = var.bridge_device
  isolated_network_id           = local.internal_network_id
  isolated_network_name         = local.internal_network_name
  storage_pool                  = var.storage_pool
  userdata                      = libvirt_cloudinit_disk.userdata.id
  host_ips                      = local.hana_ips
  block_devices                 = local.hana_block_devices
  hana_data_disks_configuration = var.hana_data_disks_configuration
  sbd_disk_id                   = module.hana_sbd_disk.id
  iscsi_srv_ip                  = module.iscsi_server.output_data.private_addresses.0
  scale_out_nfs                 = var.hana_scale_out_nfs
  # passed to majority_maker module
  majority_maker_node_vcpu   = var.majority_maker_node_vcpu
  majority_maker_node_memory = var.majority_maker_node_memory
  majority_maker_ip          = local.hana_majority_maker_ip
}

module "drbd_node" {
  source                = "./modules/drbd_node"
  common_variables      = module.common_variables.configuration
  name                  = var.drbd_name
  network_domain        = var.drbd_network_domain == "" ? var.network_domain : var.drbd_network_domain
  source_image          = var.drbd_source_image
  volume_name           = var.drbd_source_image != "" ? "" : (var.drbd_volume_name != "" ? var.drbd_volume_name : local.generic_volume_name)
  drbd_count            = var.drbd_enabled == true ? 2 : 0
  vcpu                  = var.drbd_node_vcpu
  memory                = var.drbd_node_memory
  bridge                = var.bridge_device
  host_ips              = local.drbd_ips
  drbd_disk_size        = var.drbd_disk_size
  sbd_disk_id           = module.drbd_sbd_disk.id
  iscsi_srv_ip          = module.iscsi_server.output_data.private_addresses.0
  isolated_network_id   = local.internal_network_id
  isolated_network_name = local.internal_network_name
  storage_pool          = var.storage_pool
  userdata              = libvirt_cloudinit_disk.userdata.id
  nfs_mounting_point    = var.nfs_mounting_point
  nfs_export_name       = var.netweaver_sid
}

module "monitoring" {
  source                = "./modules/monitoring"
  common_variables      = module.common_variables.configuration
  name                  = var.monitoring_name
  network_domain        = var.monitoring_network_domain == "" ? var.network_domain : var.monitoring_network_domain
  monitoring_enabled    = var.monitoring_enabled
  source_image          = var.monitoring_source_image
  volume_name           = var.monitoring_source_image != "" ? "" : (var.monitoring_volume_name != "" ? var.monitoring_volume_name : local.generic_volume_name)
  vcpu                  = var.monitoring_vcpu
  memory                = var.monitoring_memory
  bridge                = var.bridge_device
  storage_pool          = var.storage_pool
  userdata              = libvirt_cloudinit_disk.userdata.id
  isolated_network_id   = local.internal_network_id
  isolated_network_name = local.internal_network_name
  monitoring_srv_ip     = local.monitoring_srv_ip
}

module "netweaver_node" {
  source                = "./modules/netweaver_node"
  common_variables      = module.common_variables.configuration
  name                  = var.netweaver_name
  network_domain        = var.netweaver_network_domain == "" ? var.network_domain : var.netweaver_network_domain
  xscs_server_count     = local.netweaver_xscs_server_count
  app_server_count      = var.netweaver_enabled ? var.netweaver_app_server_count : 0
  source_image          = var.netweaver_source_image
  volume_name           = var.netweaver_source_image != "" ? "" : (var.netweaver_volume_name != "" ? var.netweaver_volume_name : local.generic_volume_name)
  vcpu                  = var.netweaver_node_vcpu
  memory                = var.netweaver_node_memory
  bridge                = var.bridge_device
  storage_pool          = var.storage_pool
  userdata              = libvirt_cloudinit_disk.userdata.id
  isolated_network_id   = local.internal_network_id
  isolated_network_name = local.internal_network_name
  host_ips              = local.netweaver_ips
  virtual_host_ips      = local.netweaver_virtual_ips
  shared_disk_id        = module.netweaver_shared_disk.id
  iscsi_srv_ip          = module.iscsi_server.output_data.private_addresses.0
  netweaver_inst_media  = var.netweaver_inst_media
}
