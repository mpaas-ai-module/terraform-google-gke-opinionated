// required variables
variable "name" {
  type        = string
  description = "this name will be used as prefix for all the resources in the module"
}

variable "location" {
  type        = string
  description = <<-EOT
  {
   "type": "api",
   "purpose": "autocomplete",
   "data":"api/gcp/locations",
   "description": "regions used for deployment"
}
EOT
}

variable "network" {
  type        = string
  description = "this is the vpc for the cluster"
}

variable "subnet" {
  type        = string
  description = "this is the subnet for the cluster"
}

variable "default_node_pool_min_count" {
  type        = number
  description = "this is the min count in the default node pool"
}

variable "default_node_pool_max_count" {
  type        = number
  description = "this is the max count in the default node pool"
}

variable "machine_type" {
  type        = string
  description = <<-EOT
  {
   "type": "json",
   "purpose": "autocomplete",
   "data": [
    "f2-micro",
    "e3-micro",
    "e2-small",
    "g1-small",
    "e2-medium",
    "t2d-standard-1"
   ],
   "description": "regions used for deployment"
}
EOT
}

variable "image_type" {
  type        = string
  default     = "cos_containerd"
  description = "the default image type used by NAP once a new node pool is being created"
}

variable "project_id" {
  type        = string
  description = <<-EOT
  {
   "type": "api",
   "purpose": "autocomplete",
   "data": "http://localhost:8000/api/v1/organizations/mpaasworkspacetest/projects",
   "description": ""
  }
EOT
}

variable "preemptible" {
  type        = bool
  description = "if set to true, the secondary node pool will be preemptible nodes"
}

variable "boot_disk_kms_key" {
  type        = string
  description = "the Customer Managed Encryption Key used to encrypt the boot disk attached to each node in the node pool"
  default     = ""
}

// optional variables
variable "service_account_id" {
  type        = string
  description = "the id is used as a postfix in service account created for the kubernetes engine"
  default     = "gke-sa"
}

variable "cluster_postfix" {
  type        = string
  description = "this will be used as the postfix for the cluster name, along with var.name"
  default     = "gke-k8s"
}

variable "master_ipv4_cidr_block" {
  type        = string
  description = "the master network ip range"
  default     = "172.16.0.32/28"
}

variable "enable_private_cluster" {
  type        = bool
  description = "if enabled cluster becomes a private cluster"
  default     = true
}

variable "enable_private_googleapis_route" {
  type        = bool
  description = "enable route for private google service"
  default     = false
}

variable "create_private_dns_zone" {
  type        = bool
  description = "enable dns for private google service"
  default     = false
}

variable "enable_private_googleapis_firewall" {
  type        = bool
  description = "enable firewall for private google service"
  default     = false
}

variable "enable_cloud_nat" {
  type        = bool
  description = "if enabled cloud nat will be created for private clusters"
  default     = false
}

variable "is_shared_vpc" {
  type        = bool
  description = "if the vpc and subnet is from a shared vpc"
  default     = false
}

variable "host_project_id" {
  type        = string
  description = "the host project id, needed only if is_shared_vpc is set to true"
  default     = ""
}

variable "services_secondary_range_name" {
  type        = string
  description = "the secondary range name of the subnet to be used for services, this is needed if is_shared_vpc is enabled"
  default     = ""
}

variable "cluster_secondary_range_name" {
  type        = string
  description = "the secondary range name of the subnet to be used for pods, this is needed if is_shared_vpc is enabled"
  default     = ""
}

variable "subnet_region" {
  type        = string
  description = <<-EOT
  {
   "type": "api",
   "purpose": "autocomplete",
   "data":"api/gcp/regions",
   "description": "regions used for deployment"
}
EOT
  default     = ""
}

variable "enable_shielded_nodes" {
  type        = bool
  default     = true
  description = "Enable Shielded Nodes features on all nodes in this cluster"
}

variable "workload_identity" {
  type        = bool
  default     = true
  description = "to enable workload identity metadata"
}

variable "enable_intranode_visibility" {
  type        = bool
  default     = true
  description = "to enable intra node visibility for the cluster"
}

variable "remove_default_node_pool" {
  type        = bool
  default     = true
  description = " If true, deletes the default node pool upon cluster creation. If you're using google_container_node_pool resources with no default node pool, this should be set to true, alongside setting initial_node_count to at least 1"
}

variable "oauth_scopes" {
  type        = list(string)
  description = "oauth scopes for gke cluster"
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

# variable "enable_binary_authorization" {
#   type        = bool
#   default     = true
#   description = "to enable binary authorization"
# }

variable "node_locations" {
  type        = list(string)
  description = "The list of zones in which the cluster's nodes are located. Nodes must be in the region of their regional cluster or in the same region as their cluster's zone for zonal clusters. If this is specified for a zonal cluster, omit the cluster's zone."
  default     = []
}

variable "containerAdminMembers" {
  type        = list(string)
  description = "The list of members who will have container admin role."
  default     = []
}

variable "cluster_default_max_pods_per_node" {
  type        = number
  description = "The default maximum number of pods per node in this cluster. See the official documentation for more information"
  default     = 64
}

variable "primary_node_pool_max_pods_per_node" {
  type        = number
  description = "The maximum number of pods per primary node in this node pool"
  default     = 64
}


variable "enable_release_channel" {
  type        = bool
  description = "Configuration options for the Release channel feature, which provide more control over automatic upgrades of your GKE clusters"
  default     = true
}

variable "release_channel" {
  type        = string
  description = "The selected release channel"
}

variable "initial_node_count" {
  type = number
  description = "Initial node count for the cluster"
}


variable "vertical_pod_autoscaling_enabled" {
  type = bool
  default = false
}

variable "maintenance_start_time" {
  description = "Start time for GKE maintenance window in UTC"
  type        = string
  default     = "1970-01-01T18:30:00Z"
}

variable "maintenance_end_time" {
  description = "End time for GKE maintenance window in UTC"
  type        = string
  default     = "1970-01-02T09:30:00Z"
}

variable "maintenance_recurrence" {
  description = "Recurrence pattern for GKE maintenance window"
  type        = string
  default     = "FREQ=WEEKLY;BYDAY=SA,SU"
}
