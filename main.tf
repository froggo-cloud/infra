terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.19"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}