resource "google_project_service" "pubsub" {
  project            = var.project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "bigquery" {
  project            = var.project_id
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "aiplatform" {
  project            = var.project_id
  service            = "aiplatform.googleapis.com"
  disable_on_destroy = false
}

resource "google_pubsub_topic" "telemetry" {
  name    = "greenedge-${var.environment}-telemetry"
  project = var.project_id

  depends_on = [
    google_project_service.pubsub
  ]
}

resource "google_bigquery_dataset" "telemetry" {
  dataset_id                 = "greenedge_${var.environment}"
  project                    = var.project_id
  location                   = var.region
  delete_contents_on_destroy = false

  depends_on = [
    google_project_service.bigquery
  ]
}

resource "google_bigquery_table" "telemetry" {
  project             = var.project_id
  dataset_id          = google_bigquery_dataset.telemetry.dataset_id
  table_id            = "sensor_telemetry"
  deletion_protection = true

  time_partitioning {
    type  = "DAY"
    field = "timestamp"
  }

  clustering = ["site_id", "device_id"]

  schema = jsonencode([
    {
      name = "event_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "device_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "site_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "timestamp"
      type = "TIMESTAMP"
      mode = "REQUIRED"
    },
    {
      name = "temperature_c"
      type = "FLOAT"
      mode = "NULLABLE"
    },
    {
      name = "humidity_pct"
      type = "FLOAT"
      mode = "NULLABLE"
    },
    {
      name = "power_kw"
      type = "FLOAT"
      mode = "REQUIRED"
    },
    {
      name = "occupancy"
      type = "INT64"
      mode = "NULLABLE"
    }
  ])
}

resource "google_bigquery_table" "knowledge_chunks" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.telemetry.dataset_id
  table_id   = "knowledge_chunks"

  deletion_protection = true

  schema = jsonencode([
    {
      name = "chunk_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "source"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "content"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "embedding"
      type = "FLOAT64"
      mode = "REPEATED"
    },
    {
      name = "created_at"
      type = "TIMESTAMP"
      mode = "REQUIRED"
    }
  ])

  depends_on = [
    google_project_service.aiplatform
  ]
}

resource "google_pubsub_subscription" "bigquery" {
  name    = "greenedge-${var.environment}-bigquery"
  project = var.project_id
  topic   = google_pubsub_topic.telemetry.id

  bigquery_config {
    table               = "${var.project_id}.${google_bigquery_dataset.telemetry.dataset_id}.${google_bigquery_table.telemetry.table_id}"
    use_table_schema    = true
    write_metadata      = false
    drop_unknown_fields = false
  }

  depends_on = [
    google_bigquery_table.telemetry,
    google_project_iam_member.pubsub_bigquery_writer,
    google_project_iam_member.pubsub_bigquery_job_user
  ]
}



# Configure BigQuery write permissions
data "google_project" "current" {
  project_id = var.project_id
}

resource "google_project_iam_member" "pubsub_bigquery_writer" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"

  member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "pubsub_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"

  member = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}


# Auth Part
# 1. Workload Identity Pool
resource "google_iam_workload_identity_pool" "aws" {
  project                   = var.project_id
  workload_identity_pool_id = "greenedge-aws-pool"
  display_name              = "GreenEdge AWS Workloads"
  description               = "Trust AWS Lambda workloads for GreenEdge AI"
}

# 2. AWS identity provider
resource "google_iam_workload_identity_pool_provider" "aws" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.aws.workload_identity_pool_id
  workload_identity_pool_provider_id = "greenedge-aws-provider"
  display_name                       = "GreenEdge AWS Provider"

  aws {
    account_id = var.aws_account_id
  }

  attribute_mapping = {
    "google.subject"     = "assertion.arn"
    "attribute.aws_role" = "assertion.arn.extract('assumed-role/{role_name}/')"
  }

  attribute_condition = <<-EOT
    assertion.account == "${var.aws_account_id}" &&
    assertion.arn.startsWith("arn:aws:sts::${var.aws_account_id}:assumed-role/${var.aws_lambda_role_name}/")
  EOT
}

# 3. Dedicated Google service account
resource "google_service_account" "lambda_publisher" {
  project      = var.project_id
  account_id   = "greenedge-lambda-publisher"
  display_name = "GreenEdge Lambda Pub/Sub Publisher"
}

# 4. Allow only the trusted AWS Lambda role to impersonate this service account
resource "google_service_account_iam_member" "aws_lambda_federation" {
  service_account_id = google_service_account.lambda_publisher.name
  role               = "roles/iam.workloadIdentityUser"

  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.aws.name}/*"
}

# 5. Allow the service account to publish to the telemetry topic only
resource "google_pubsub_topic_iam_member" "lambda_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.telemetry.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.lambda_publisher.email}"
}

resource "google_billing_budget" "greenedge_dev" {
  billing_account = var.billing_account_id
  display_name    = "GreenEdge AI Development Budget"

  budget_filter {
    projects = [
      "projects/${var.project_number}"
    ]
  }

  amount {
    specified_amount {
      currency_code = "INR"
      units         = "500"
    }
  }

  threshold_rules {
    threshold_percent = 0.50
  }

  threshold_rules {
    threshold_percent = 0.80
  }

  threshold_rules {
    threshold_percent = 1.00
  }
}

# Enable these Services
resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifact_registry" {
  project            = var.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam_credentials" {
  project            = var.project_id
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "greenedge" {
  project       = var.project_id
  location      = var.region
  repository_id = "greenedge"
  description   = "GreenEdge AI application images"
  format        = "DOCKER"

  depends_on = [
    google_project_service.artifact_registry
  ]
}

resource "google_service_account" "cloud_run" {
  project      = var.project_id
  account_id   = "greenedge-cloud-run"
  display_name = "GreenEdge Cloud Run Runtime"
}

resource "google_project_iam_member" "cloud_run_bigquery_job" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_bigquery_dataset_iam_member" "cloud_run_bigquery_reader" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.telemetry.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.cloud_run.email}"
}

resource "google_project_iam_member" "cloud_run_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}


variable "cloud_run_service_name" {
  type    = string
  default = "greenedge-api"
}

resource "google_cloud_run_v2_service" "api" {
  project  = var.project_id
  name     = var.cloud_run_service_name
  location = var.region

  deletion_protection = false

  template {
    service_account = google_service_account.cloud_run.email

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    containers {
      # Initial placeholder. The GitHub deployment workflow
      # will replace this with a commit-specific image.
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      ports {
        container_port = 8080
      }

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "GCP_REGION"
        value = var.region
      }

      env {
        name  = "BQ_DATASET"
        value = var.bigquery_dataset_id
      }

      env {
        name  = "TELEMETRY_TABLE"
        value = "sensor_telemetry"
      }

      env {
        name  = "KNOWLEDGE_TABLE"
        value = "knowledge_chunks"
      }

      env {
        name  = "GEMINI_MODEL"
        value = "gemini-2.5-flash"
      }
    }
  }

  depends_on = [
    google_project_iam_member.cloud_run_bigquery_job,
    google_bigquery_dataset_iam_member.cloud_run_bigquery_reader,
    google_project_iam_member.cloud_run_vertex,
    google_project_service.run
  ]
}


resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "greenedge-github-pool"
  display_name              = "GreenEdge GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "greenedge-github-provider"
  display_name                       = "GreenEdge GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository == '${var.github_repository}' && assertion.ref == 'refs/heads/main'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}


resource "google_service_account" "github_deployer" {
  project      = var.project_id
  account_id   = var.github_deployment_service_account_id
  display_name = "GreenEdge GitHub Actions Deployer"
}

resource "google_service_account_iam_member" "github_wif" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"

  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

resource "google_project_iam_member" "github_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

resource "google_project_iam_member" "github_cloud_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

resource "google_service_account_iam_member" "github_run_act_as" {
  service_account_id = google_service_account.cloud_run.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_deployer.email}"
}