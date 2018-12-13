resource "google_compute_firewall" "tcp_internal" {
  name    = "${var.env_name}-cf-internal-tcp"
  network = "${var.network}"

  allow {
    protocol = "tcp"
    ports    = ["1024-65535"]
  }

  source_ranges = [
    "${var.pas_cidr}",
    "${var.services_cidr}",
  ]

  target_tags = ["${var.env_name}-tcp-lb"]
}

resource "google_compute_instance_group" "tcp-internal-lb" {
  // Count based on number of AZs
  count       = "${var.use_internal_lb ? 3 : 0}"
  name        = "${var.env_name}-tcp-internal-lb-${element(var.zones, count.index)}"
  description = "Terraform generated instance group that is multi-zone for Internal Load Balancing"
  zone        = "${element(var.zones, count.index)}"
  network     = "${var.network}"
}

resource "google_compute_firewall" "tcp_lb_health_check" {
  name    = "${var.env_name}-tcp-lb-health-check"
  network = "${var.network}"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  target_tags = ["${var.env_name}-tcp-lb"]
}

resource "google_compute_health_check" "tcp_internal" {
  name                = "${var.env_name}-tcp-internal"
  check_interval_sec  = 30
  timeout_sec         = 5
  healthy_threshold   = 10
  unhealthy_threshold = 2

  http_health_check {
    request_path = "/health"
    port         = "80"
  }

  count = "${var.use_internal_lb ? 1 : 0}"
}

resource "google_compute_region_backend_service" "tcp_internal" {
  name        = "${var.env_name}-tcp-lb"
  protocol    = "TCP"
  timeout_sec = 900

  backend {
    group = "${google_compute_instance_group.tcp-internal-lb.0.self_link}"
  }

  backend {
    group = "${google_compute_instance_group.tcp-internal-lb.1.self_link}"
  }

  backend {
    group = "${google_compute_instance_group.tcp-internal-lb.2.self_link}"
  }

  health_checks = ["${google_compute_health_check.tcp_internal.self_link}"]

  count = "${var.use_internal_lb ? 1 : 0}"
}

resource "google_compute_forwarding_rule" "tcp_internal" {
  name                  = "${var.env_name}-tcp-internal-lb"
  backend_service       = "${google_compute_region_backend_service.tcp_internal.self_link}"
  network               = "${var.network}"
  subnetwork            = "${var.subnetwork_name}"
  load_balancing_scheme = "INTERNAL"
  ip_protocol           = "TCP"
  ports                 = ["1024", "1025", "1026", "1027", "1028"]
}