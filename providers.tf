locals {
  tags_labels = { "created-by" = "terraform" }
}

provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = local.tags_labels
  }
}

provider "tfe" {
  hostname = var.tf_hostname
}
