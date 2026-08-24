# Where Terraform keeps the state of this environment.
#
# It is local, in this directory. That is honest for a lab that one person
# applies from one machine, and it is the reason the block below is commented
# out: the bucket and the lock table do not exist, and an uncommented backend
# pointing at a bucket that is not there fails on `terraform init`.
#
# The moment a second person applies this, or a pipeline does, the state has to
# move to a shared backend. Each environment gets its own key, so dev cannot
# overwrite prod:
#
# terraform {
#   backend "s3" {
#     bucket       = "my-terraform-state-bucket"
#     key          = "project4/dev/terraform.tfstate"
#     region       = "eu-west-2"
#     encrypt      = true
#     use_lockfile = true
#   }
# }
#
# The state file is not a log: it holds every attribute of every resource,
# including values marked sensitive. It belongs in a private, versioned,
# encrypted bucket and never in Git.
