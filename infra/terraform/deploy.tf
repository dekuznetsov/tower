# -----------------------------------------------------------------------------
# Deployment glue. Terraform's Firebase providers cannot upload Hosting files,
# set RTDB security rules, or write RTDB data, so those steps run through the
# Firebase CLI, invoked from Terraform and ordered via depends_on.
# -----------------------------------------------------------------------------

# Render web/.env from the provisioned web app config (consumed by `vite build`).
resource "local_file" "web_env" {
  filename        = "${path.module}/${var.web_dir}/.env"
  file_permission = "0600"
  content         = <<-EOT
    VITE_FB_API_KEY=${data.google_firebase_web_app_config.default.api_key}
    VITE_FB_AUTH_DOMAIN=${data.google_firebase_web_app_config.default.auth_domain}
    VITE_FB_PROJECT_ID=${var.project_id}
    VITE_FB_APP_ID=${google_firebase_web_app.default.app_id}
    VITE_FB_SENDER_ID=${data.google_firebase_web_app_config.default.messaging_sender_id}
    VITE_FB_DATABASE_URL=${google_firebase_database_instance.default.database_url}
  EOT
}

# Tower seed — only the inner tower node, so seeding never clobbers /allowlist.
data "local_file" "seed_source" {
  filename = "${path.module}/../../firebase/seed_data.json"
}

resource "local_file" "tower_seed" {
  filename = "${path.module}/generated/tower_seed.json"
  content  = jsonencode(jsondecode(data.local_file.seed_source.content).farms.farm_id_1.towers.tower_1)
}

# Allowlist document generated from the configured UIDs: { "<uid>": true, ... }.
resource "local_file" "allowlist" {
  filename = "${path.module}/generated/allowlist.json"
  content  = jsonencode({ for uid in var.allowlist_uids : uid => true })
}

# Deploy security rules, seed the tower node, and merge the allowlist (idempotent).
resource "null_resource" "backend_deploy" {
  count = var.run_deploy ? 1 : 0

  triggers = {
    rules     = filesha256("${path.module}/../../firebase/database.rules.json")
    tower     = local_file.tower_seed.content
    allowlist = local_file.allowlist.content
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "PROJECT_ID='${var.project_id}' bash '${path.module}/scripts/deploy_backend.sh'"
  }

  depends_on = [
    google_firebase_database_instance.default,
    local_file.tower_seed,
    local_file.allowlist,
  ]
}

# Deploy the monitoring Cloud Functions (Google Chat alerts). The webhook secret
# is provisioned above; `firebase deploy` builds via the predeploy hook.
resource "null_resource" "functions_deploy" {
  count = var.run_deploy && var.deploy_functions ? 1 : 0

  triggers = {
    run_at = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "cd '${path.module}/../../functions' && npm ci && firebase deploy --only functions --project '${var.project_id}' --non-interactive"
  }

  depends_on = [
    google_firebase_database_instance.default,
    google_secret_manager_secret_version.chat_webhook,
  ]
}

# Build the web app and publish a Hosting release.
resource "null_resource" "hosting_deploy" {
  count = var.run_deploy ? 1 : 0

  triggers = {
    run_at = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "cd '${path.module}/${var.web_dir}' && npm ci && npm run build && firebase deploy --only hosting --project '${var.project_id}' --non-interactive"
  }

  depends_on = [
    google_firebase_hosting_site.default,
    local_file.web_env,
  ]
}
