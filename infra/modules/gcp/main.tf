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