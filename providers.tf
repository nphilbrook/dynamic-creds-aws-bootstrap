locals {
  tags_labels = { "created-by" = "terraform",
    "source-workspace-slug" = var.TFC_WORKSPACE_SLUG
  }
}

provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = local.tags_labels
  }
}

provider "tfe" {
  hostname     = var.tf_hostname
  organization = var.tf_organization_name
}
