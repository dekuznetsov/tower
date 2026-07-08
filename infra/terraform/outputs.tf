output "web_config" {
  description = "Firebase web SDK configuration (safe to expose in the browser bundle)."
  value = {
    apiKey            = data.google_firebase_web_app_config.default.api_key
    authDomain        = data.google_firebase_web_app_config.default.auth_domain
    projectId         = var.project_id
    appId             = google_firebase_web_app.default.app_id
    messagingSenderId = data.google_firebase_web_app_config.default.messaging_sender_id
    databaseURL       = google_firebase_database_instance.default.database_url
  }
}

output "database_url" {
  description = "Realtime Database URL."
  value       = google_firebase_database_instance.default.database_url
}

output "hosting_url" {
  description = "Public URL of the Hosting site."
  value       = "https://${google_firebase_hosting_site.default.site_id}.web.app"
}

output "web_app_id" {
  description = "Firebase web app id."
  value       = google_firebase_web_app.default.app_id
}
