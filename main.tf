resource "google_service_account" "default" {
  account_id   = "${var.name}-sa"
  display_name = "${var.name}-sa"
  project      = var.project_id
}

resource "google_container_cluster" "primary" {
  project                     = var.project_id
  name                        = "${var.name}-${var.cluster_postfix}"
  location                    = var.location
  node_locations              = length(var.node_locations) != 0 ? var.node_locations : null
  networking_mode             = "VPC_NATIVE"
  network                     = var.network
  subnetwork                  = var.subnet
  enable_shielded_nodes       = var.enable_shielded_nodes
  enable_intranode_visibility = var.enable_intranode_visibility
  vertical_pod_autoscaling {
    enabled = var.vertical_pod_autoscaling_enabled
  }


  ip_allocation_policy {
    cluster_ipv4_cidr_block       = var.is_shared_vpc ? null : "/14"
    services_ipv4_cidr_block      = var.is_shared_vpc ? null : "/16"
    cluster_secondary_range_name  = var.is_shared_vpc ? var.cluster_secondary_range_name : null
    services_secondary_range_name = var.is_shared_vpc ? var.services_secondary_range_name : null
  }

  remove_default_node_pool  = var.remove_default_node_pool
  initial_node_count        = var.initial_node_count
  default_max_pods_per_node = var.cluster_default_max_pods_per_node

  dynamic "release_channel" {
    for_each = var.enable_release_channel ? [1] : []
    content {
      channel = var.release_channel
    }
  }

  dynamic "master_authorized_networks_config" {
    for_each = var.enable_private_cluster == true ? [1] : []
    content {
    }
  }

  dynamic "workload_identity_config" {
    for_each = var.workload_identity ? [1] : []
    content {
      workload_pool = "${var.project_id}.svc.id.goog"
    }
  }

  private_cluster_config {
    enable_private_nodes    = var.enable_private_cluster
    enable_private_endpoint = var.enable_private_cluster
    master_ipv4_cidr_block  = var.enable_private_cluster ? var.master_ipv4_cidr_block : null

    master_global_access_config {
      enabled = true
    }
  }
  node_config {
    service_account = google_service_account.default.email
    machine_type    = var.machine_type
    image_type      = var.image_type
    //not advisable to use preemptible nodes for default node pool
    oauth_scopes = tolist(var.oauth_scopes)
    dynamic "workload_metadata_config" {
      for_each = var.workload_identity ? [1] : []
      content {
        mode = "GKE_METADATA"
      }
    }
    dynamic "shielded_instance_config" {
      for_each = var.enable_shielded_nodes ? [1] : []
      content {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }
    }
  }

  lifecycle {
    ignore_changes = [
      node_config,initial_node_count
    ]
  }
  
  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start_time
      end_time   = var.maintenance_end_time
      recurrence = var.maintenance_recurrence
    }
  }

  depends_on = [
    google_project_iam_member.project,
    google_compute_subnetwork_iam_member.cloudservices,
    google_compute_subnetwork_iam_member.container_engine_robot,
  ]
}

resource "google_container_node_pool" "primary_node_pool" {
  project            = var.project_id
  name               = "${var.name}-primary-node-pool"
  location           = var.location
  cluster            = google_container_cluster.primary.name
  initial_node_count = var.initial_node_count
  max_pods_per_node  = var.primary_node_pool_max_pods_per_node

  autoscaling {
    min_node_count = var.default_node_pool_min_count
    max_node_count = var.default_node_pool_max_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    service_account   = google_service_account.default.email
    machine_type      = var.machine_type
    image_type        = var.image_type
    # boot_disk_kms_key = var.boot_disk_kms_key

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    oauth_scopes = tolist(var.oauth_scopes)
    dynamic "workload_metadata_config" {
      for_each = var.workload_identity ? [1] : []
      content {
        mode = "GKE_METADATA"
      }
    }
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to node_config, because it usually always changes after
      # resource is created
      node_config,initial_node_count
    ]
  }

  depends_on = [
    google_project_iam_member.project,
    google_compute_subnetwork_iam_member.cloudservices,
    google_compute_subnetwork_iam_member.container_engine_robot,
  ]
}


//Enable a route to default internet gateway
//Enable this if private google access is being used, check compatibility with automatically created dns zone in host project
//Don't use this if cloud NAT is enabled
resource "google_compute_route" "route" {
  count            = var.enable_private_cluster && var.enable_private_googleapis_route ? 1 : 0
  name             = "private-googleapis-route"
  project          = var.host_project_id
  dest_range       = "199.36.153.8/30"
  network          = var.network
  next_hop_gateway = "default-internet-gateway"
  priority         = 0
}

//Allow health check probes to reach cluster(cluster creation fails at health check without this)
//Don't use this if cloud NAT is enabled
resource "google_compute_firewall" "health-ingress-firewall" {
  count         = var.enable_private_cluster && var.enable_private_googleapis_firewall ? 1 : 0
  name          = "health-check-ingress"
  network       = var.network
  project       = var.host_project_id
  direction     = "INGRESS"
  priority      = 0
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  allow {
    protocol = "tcp"
  }
}

//Allow cluster to reach health check probes(not verified if we really need this)
//Don't use this if cloud NAT is enabled
resource "google_compute_firewall" "health-egress-firewall" {
  count              = var.enable_private_cluster && var.enable_private_googleapis_firewall ? 1 : 0
  name               = "health-check-egress"
  network            = var.network
  project            = var.host_project_id
  direction          = "EGRESS"
  priority           = 0
  destination_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  allow {
    protocol = "tcp"
  }
}

//Allow cluster to reach private.googleapis.com(alternative restricted.googleapis.com can also be used)
//Don't use this if cloud NAT is enabled
resource "google_compute_firewall" "googleapis-egress-firewall" {
  count              = var.enable_private_cluster && var.enable_private_googleapis_firewall ? 1 : 0
  name               = "googleapis-egress"
  network            = var.network
  project            = var.host_project_id
  direction          = "EGRESS"
  priority           = 0
  destination_ranges = ["199.36.153.8/30"]

  allow {
    protocol = "tcp"
  }
}

//Create an external NAT IP
//Don't use this if private google access is being used
resource "google_compute_address" "nat" {
  count   = var.enable_private_cluster && var.enable_cloud_nat ? 1 : 0
  name    = format("%s-nat-ip", var.name)
  project = var.host_project_id
  region  = var.subnet_region
}

//Create a cloud router for use by the Cloud NAT
//Don't use this if private google access is being used
resource "google_compute_router" "router" {
  count   = var.enable_private_cluster && var.enable_cloud_nat ? 1 : 0
  name    = format("%s-cloud-router", var.name)
  project = var.host_project_id
  network = var.network
  region  = var.subnet_region

  bgp {
    asn = 64514
  }
}

//Create a NAT router so the nodes can reach DockerHub, etc
//Don't use this if private google access is being used
resource "google_compute_router_nat" "nat" {
  count   = var.enable_private_cluster && var.enable_cloud_nat ? 1 : 0
  name    = format("%s-cloud-nat", var.name)
  project = var.host_project_id
  router  = google_compute_router.router[0].name
  region  = google_compute_router.router[0].region

  nat_ip_allocate_option = "MANUAL_ONLY"

  nat_ips = [google_compute_address.nat[0].self_link]

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = var.subnet
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE", "LIST_OF_SECONDARY_IP_RANGES"]

    secondary_ip_range_names = [
      var.cluster_secondary_range_name,
      var.services_secondary_range_name,
    ]
  }
}

module "gcr-dns" {
  count                              = var.enable_private_cluster && var.create_private_dns_zone ? 1 : 0
  source                             = "../terraform-google-dns-managed-zone" # PoC fork: registry 1.0.10 pins provider =4.1.0 (transitive conflict)
  name                               = "gcr-io"
  dns_name                           = "gcr.io."
  is_private                         = true
  force_destroy                      = true
  description                        = "private zone for GCR.io"
  project                            = var.project_id
  private_visibility_config_networks = [var.network]
  records = [
    {
      name    = "*.gcr.io."
      type    = "CNAME"
      ttl     = "300"
      rrdatas = ["gcr.io."]
    },
    {
      name = "gcr.io."
      type = "A"
      ttl  = "300"
      rrdatas = [
        "199.36.153.10",
        "199.36.153.11",
        "199.36.153.8",
        "199.36.153.9"
      ]
    }
  ]
}

module "googleapis-dns" {
  count                              = var.enable_private_cluster && var.enable_private_googleapis_route && var.create_private_dns_zone ? 1 : 0
  source                             = "../terraform-google-dns-managed-zone" # PoC fork: registry 1.0.10 pins provider =4.1.0 (transitive conflict)
  name                               = "googleapis-com"
  dns_name                           = "googleapis.com."
  is_private                         = true
  force_destroy                      = true
  description                        = "private zone for googleapis.com"
  project                            = var.project_id
  private_visibility_config_networks = [var.network]
  records = [
    {
      name    = "*.googleapis.com."
      type    = "CNAME"
      ttl     = "300"
      rrdatas = ["private.googleapis.com."]
    },
    {
      name = "private.googleapis.com."
      type = "A"
      ttl  = "300"
      rrdatas = [
        "199.36.153.10",
        "199.36.153.11",
        "199.36.153.8",
        "199.36.153.9"
      ]
    }
  ]
}

data "google_project" "service_project6" {
  project_id = var.project_id
}
resource "google_project_iam_binding" "network_binding7" {
  count   = 1
  project = var.project_id
  role    = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members = [
    "serviceAccount:service-${data.google_project.service_project6.number}@compute-system.iam.gserviceaccount.com","serviceAccount:service-${data.google_project.service_project6.number}@container-engine-robot.iam.gserviceaccount.com"
  ]
  lifecycle {
    ignore_changes = [ members ]
  }

}