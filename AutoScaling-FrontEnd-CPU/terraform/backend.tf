terraform {
  backend "s3" {
    # S3 bucket for state storage - specify via -backend-config or backend.hcl
    # Example:
    #   bucket  = "ostad-terraform-state-bmi-sarowar-ap-south-1"
    #   key     = "bmi-autoscaling/terraform.tfstate"
    #   region  = "ap-south-1"
    #   encrypt = true
    #
    # Or initialize with:
    #   terraform init -backend-config=backend.hcl
  }
}
