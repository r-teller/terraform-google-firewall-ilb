resource "random_id" "suffix" {
  byte_length = 2
}

data "google_compute_network" "network" {
  project = var.project_id
  name    = var.network
}

data "google_compute_subnetwork" "subnetwork" {
  project = var.project_id
  name    = var.subnetwork
}

resource "google_compute_region_backend_service" "backend_service" {
  project  = var.project_id
  name     = "backend-${var.name}-${random_id.suffix.hex}"
  region   = var.region
  protocol = var.ip_protocol
  network  = data.google_compute_network.network.self_link

  # Do not try to add timeout_sec, as it is has no impact. See https://github.com/terraform-google-modules/terraform-google-lb-internal/issues/53#issuecomment-893427675
  connection_draining_timeout_sec = var.connection_draining_timeout_sec
  session_affinity                = var.session_affinity
  dynamic "backend" {
    for_each = { for backend in var.backends : backend.id => backend }
    content {
      group       = backend.value.id
      description = null
    }
  }
  health_checks = [
    var.health_check["type"] == "tcp" ? google_compute_health_check.health_check_tcp[0].self_link :
    var.health_check["type"] == "http" ? google_compute_health_check.health_check_http[0].self_link :
  google_compute_health_check.health_check_https[0].self_link]
}

resource "google_compute_forwarding_rule" "forwarding_rule" {
  project               = var.project_id
  name                  = "forwarder-${var.name}-${random_id.suffix.hex}"
  region                = var.region
  network               = data.google_compute_network.network.self_link
  subnetwork            = data.google_compute_subnetwork.subnetwork.self_link
  allow_global_access   = var.global_access
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.backend_service.self_link
  ip_address            = var.ip_address
  ip_protocol           = var.ip_protocol
  ports                 = var.ports
  all_ports             = var.all_ports
  service_label         = var.service_label
}

resource "google_compute_route" "route" {
  for_each     = { for dest_range in var.dest_ranges : dest_range.range => dest_range }
  name         = "route-${var.name}-${replace(each.value.range, "//|\\./", "-")}-${random_id.suffix.hex}"
  network      = data.google_compute_network.network.self_link
  priority     = each.value.priority
  dest_range   = each.value.range
  next_hop_ilb = google_compute_forwarding_rule.forwarding_rule.id

}

resource "google_compute_health_check" "health_check_tcp" {
  provider = google-beta
  count    = var.health_check["type"] == "tcp" ? 1 : 0
  project  = var.project_id
  name     = "hc-tcp-${var.name}-${random_id.suffix.hex}"

  timeout_sec         = var.health_check["timeout_sec"]
  check_interval_sec  = var.health_check["check_interval_sec"]
  healthy_threshold   = var.health_check["healthy_threshold"]
  unhealthy_threshold = var.health_check["unhealthy_threshold"]

  tcp_health_check {
    port         = var.health_check["port"]
    request      = var.health_check["request"]
    response     = var.health_check["response"]
    port_name    = var.health_check["port_name"]
    proxy_header = var.health_check["proxy_header"]
  }

  dynamic "log_config" {
    for_each = var.health_check["enable_log"] ? [true] : []
    content {
      enable = true
    }
  }
}

resource "google_compute_health_check" "health_check_http" {
  provider = google-beta
  count    = var.health_check["type"] == "http" ? 1 : 0
  project  = var.project_id
  name     = "hc-http-${var.name}-${random_id.suffix.hex}"

  timeout_sec         = var.health_check["timeout_sec"]
  check_interval_sec  = var.health_check["check_interval_sec"]
  healthy_threshold   = var.health_check["healthy_threshold"]
  unhealthy_threshold = var.health_check["unhealthy_threshold"]

  http_health_check {
    port         = var.health_check["port"]
    request_path = var.health_check["request_path"]
    host         = var.health_check["host"]
    response     = var.health_check["response"]
    port_name    = var.health_check["port_name"]
    proxy_header = var.health_check["proxy_header"]
  }

  dynamic "log_config" {
    for_each = var.health_check["enable_log"] ? [true] : []
    content {
      enable = true
    }
  }
}

resource "google_compute_health_check" "health_check_https" {
  count   = var.health_check["type"] == "https" ? 1 : 0
  project = var.project_id
  name    = "hc-http-${var.name}-${random_id.suffix.hex}"

  timeout_sec         = var.health_check["timeout_sec"]
  check_interval_sec  = var.health_check["check_interval_sec"]
  healthy_threshold   = var.health_check["healthy_threshold"]
  unhealthy_threshold = var.health_check["unhealthy_threshold"]

  https_health_check {
    port         = var.health_check["port"]
    request_path = var.health_check["request_path"]
    host         = var.health_check["host"]
    response     = var.health_check["response"]
    port_name    = var.health_check["port_name"]
    proxy_header = var.health_check["proxy_header"]
  }

  dynamic "log_config" {
    for_each = var.health_check["enable_log"] ? [true] : []
    content {
      enable = true
    }
  }
}