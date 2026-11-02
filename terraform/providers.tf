provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "cloud-infrastructure-engineer-challenge"
      ManagedBy = "terraform"
    }
  }
}
