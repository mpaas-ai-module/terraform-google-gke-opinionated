output "default_sa_email" {
  description = "email of the gke service account"
  value       = google_service_account.default.email
}