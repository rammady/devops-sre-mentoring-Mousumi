variable "region" {
  description = "AWS region used for the backend resources"
  type        = string
  default     = "ap-south-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table used to demonstrate traditional Terraform state locking"
  type        = string
  default     = "terraform-eks-state-locks"
}
