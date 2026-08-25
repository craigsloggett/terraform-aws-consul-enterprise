terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.49.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.9.0"
    }
  }
}
