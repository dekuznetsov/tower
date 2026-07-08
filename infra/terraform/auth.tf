# Identity Platform (backs Firebase Auth). Authorized domains gate where sign-in
# may be initiated from.
resource "google_identity_platform_config" "default" {
  provider           = google-beta
  project            = var.project_id
  authorized_domains = var.authorized_domains

  depends_on = [google_firebase_project.default]
}

# Enable Google as a sign-in provider. The client id/secret originate from the
# GCP OAuth consent screen and are supplied as sensitive variables.
resource "google_identity_platform_default_supported_idp_config" "google" {
  provider      = google-beta
  project       = var.project_id
  idp_id        = "google.com"
  client_id     = var.oauth_client_id
  client_secret = var.oauth_client_secret
  enabled       = true

  depends_on = [google_identity_platform_config.default]
}
