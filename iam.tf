locals {
  if_create = var.is_shared_vpc ? 1 : 0
}

data "google_project" "host_project" {
  count      = local.if_create
  project_id = var.host_project_id
}

data "google_project" "service_project" {
  count      = local.if_create
  project_id = var.project_id
}

// project level access
// https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-shared-vpc
resource "google_project_iam_member" "project" {
  count   = local.if_create
  project = data.google_project.host_project[0].project_id
  role    = "roles/container.hostServiceAgentUser"
  member  = "serviceAccount:service-${data.google_project.service_project[0].number}@container-engine-robot.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "securityadmin" {
  count   = local.if_create
  project = data.google_project.host_project[0].project_id
  role    = "roles/compute.securityAdmin"
  member  = "serviceAccount:service-${data.google_project.service_project[0].number}@container-engine-robot.iam.gserviceaccount.com"
}

// network access
// https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-shared-vpc
resource "google_compute_subnetwork_iam_member" "cloudservices" {
  count      = local.if_create
  project    = data.google_project.host_project[0].project_id
  subnetwork = var.subnet
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${data.google_project.service_project[0].number}@cloudservices.gserviceaccount.com"
}

resource "google_compute_subnetwork_iam_member" "container_engine_robot" {
  count      = local.if_create
  project    = data.google_project.host_project[0].project_id
  subnetwork = var.subnet
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${data.google_project.service_project[0].number}@container-engine-robot.iam.gserviceaccount.com"
}

# Additive members, NOT an authoritative google_project_iam_binding.
#
# roles/container.admin is a human/CI role, so as a binding this REPLACED every
# other principal holding container.admin on the project with just
# var.containerAdminMembers — revoking access for anyone not in that list, from
# a module whose stated job is to ADD the listed members.
resource "google_project_iam_member" "containerAdmin" {
  for_each = toset(var.containerAdminMembers)
  project  = data.google_project.service_project[0].project_id
  role     = "roles/container.admin"
  member   = each.value
}

