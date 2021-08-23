locals {
  // This will create a unique map of Network and Zone combinations based on the provided instances
  // Items will only be added to the list if the instances are in the same region as var.region
  network_zone_map = {
    for i in distinct([
      for instance in data.google_compute_instance.instances : {
        network     = instance.network_interface[0].network,
        zone        = instance.zone,
        networkName = split("/", instance.network_interface[0].network)[9]
      } if 0 < length(regexall(var.region, (instance.zone != null ? instance.zone : "")))
    ]) : "${i.network}__${i.zone}" => i
  }
  session_affinity = "CLIENT_IP"
  health_check = {
    type                = "https"
    check_interval_sec  = 40
    timeout_sec         = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
    request_path        = "/php/login.php"
    enable_log          = true
    host                = ""
    port                = ""
    port_name           = "health-check-port"
    proxy_header        = "NONE"
    request             = ""
    response            = ""
  }
}

data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
}

data "google_compute_instance" "instances" {
  for_each = {
    for instance in var.instances : "${instance.Zone}/${instance.Name}" => instance
  }
  name = each.value.Name
  zone = each.value.Zone
}

// An instance can only be a member of a single instance group IF traffic is being forward to interfaces other than nic0
resource "google_compute_instance_group" "instance_group" {
  for_each = local.network_zone_map
  name     = "instance-group-${each.value.networkName}-${each.value.zone}-nlb"
  network  = each.value.network
  zone     = each.value.zone

  instances = [
    for instance in data.google_compute_instance.instances : instance.self_link
    // Since instances can only be a member of a single instance group, this IF block checks to see if the instance and instance-group belong to the same network
    if instance.zone == each.value.zone && (instance.network_interface != null ? instance.network_interface[0].network : null) == each.value.network
  ]
}

module "gce-nlb-outside" {
  source           = "../modules/load-balancer"
  name             = "gce-nlb-outside"
  project_id       = var.project_id
  backends         = [for instance_group in google_compute_instance_group.instance_group : { id = instance_group.id }]
  network          = "outside-vpc-network"
  subnetwork       = "outside-vpc-network-10-10-0-0-24-subnetwork"
  all_ports        = true
  ports            = []
  global_access    = true
  session_affinity = local.session_affinity
  region           = var.region
  dest_ranges = [{
    range    = "192.168.0.0/16",
    priority = 1000,
    }, {
    range    = "172.16.0.0/12",
    priority = 1000,
    }, {
    range    = "10.0.0.0/8",
    priority = 1000,
    }
  ]
  health_check = local.health_check
}
module "gce-nlb-inside" {
  source           = "../modules/load-balancer"
  name             = "gce-nlb-inside"
  project_id       = var.project_id
  backends         = [for instance_group in google_compute_instance_group.instance_group : { id = instance_group.id }]
  network          = "inside-vpc-network"
  subnetwork       = "inside-vpc-network-10-12-0-0-24-subnetwork"
  region           = var.region
  all_ports        = true
  ports            = []
  global_access    = true
  session_affinity = local.session_affinity
  dest_ranges = [{
    range    = "0.0.0.0/0",
    priority = 1000,
    }
  ]
  health_check = local.health_check
}