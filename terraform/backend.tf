terraform {
  backend "s3" {
    bucket         = "togglemaster-terraform-state-final"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "togglemaster-terraform-lock-final"
    encrypt        = true
  }
}
