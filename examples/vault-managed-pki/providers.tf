provider "aws" {
  region = "us-east-1"
}

# Authenticate with the VAULT_TOKEN environment variable.
provider "vault" {
  address = var.vault_address
}
