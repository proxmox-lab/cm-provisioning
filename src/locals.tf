locals {
  description      = "Provisions a Salt Master to support a Salt configuration platform."
  domain           = "home.local"
  golden_image     = "centos-2009-master-7a750ca6f"
  name             = terraform.workspace == "production" ? "salt-master" : "salt-master-${terraform.workspace}"
  tags             = {
    git_repository = var.GIT_REPOSITORY
    git_short_sha  = var.GIT_SHORT_SHA
    description    = "Managed by Terraform"
  }
}
