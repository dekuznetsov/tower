variable "project_id" {
  description = "GCP / Firebase project id."
  type        = string
}

variable "create_project" {
  description = "Create the GCP project (true) or adopt an existing one (false)."
  type        = bool
  default     = false
}

variable "project_name" {
  description = "Display name used when create_project = true."
  type        = string
  default     = "Hydroponics Farm"
}

variable "billing_account" {
  description = "Billing account id (Blaze) — required for Identity Platform and RTDB."
  type        = string
  default     = ""
}

variable "org_id" {
  description = "Organization id for project creation (optional; mutually exclusive with folder_id)."
  type        = string
  default     = ""
}

variable "region" {
  description = "Default GCP region."
  type        = string
  default     = "europe-west1"
}

variable "rtdb_region" {
  description = "Realtime Database location (us-central1 | europe-west1 | asia-southeast1)."
  type        = string
  default     = "europe-west1"
}

variable "database_instance_id" {
  description = "Realtime Database instance id (defaults to <project_id>-default-rtdb)."
  type        = string
  default     = ""
}

variable "site_id" {
  description = "Firebase Hosting site id. Recommended: equal to project_id (the default site)."
  type        = string
}

variable "authorized_domains" {
  description = "Domains authorized for Firebase Auth (include the Hosting domain and localhost)."
  type        = list(string)
  default     = ["localhost"]
}

variable "oauth_client_id" {
  description = "OAuth 2.0 client id for the Google sign-in provider (from the GCP OAuth consent screen)."
  type        = string
  sensitive   = true
}

variable "oauth_client_secret" {
  description = "OAuth 2.0 client secret for the Google sign-in provider."
  type        = string
  sensitive   = true
}

variable "allowlist_uids" {
  description = "Firebase Auth UIDs authorized to read/control the farm."
  type        = list(string)
  default     = []
}

variable "web_dir" {
  description = "Path to the web app project (relative to this module)."
  type        = string
  default     = "../../web"
}

variable "run_deploy" {
  description = "Whether Terraform should also build + deploy rules, seed, allowlist, functions and hosting via the Firebase CLI."
  type        = bool
  default     = true
}

variable "google_chat_webhook_url" {
  description = "Google Chat incoming-webhook URL for monitoring alerts. Stored in Secret Manager and consumed by the Cloud Functions."
  type        = string
  sensitive   = true
  default     = ""
}

variable "deploy_functions" {
  description = "Whether to deploy the monitoring Cloud Functions (requires google_chat_webhook_url)."
  type        = bool
  default     = true
}
