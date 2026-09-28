variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "environment" {
  type    = string
  default = "assignment"
}

variable "owner" {
  type    = string
  default = "prakash-chevula"
}

variable "ami_id" {
  description = "AMI used by all five instances (Amazon Linux 2023 in the target region)."
  type        = string
}

# Single input that drives all 5 instances — no five hardcoded resource blocks.
variable "instances" {
  description = "Map of EC2 instance definitions. Key = instance name."
  type = map(object({
    instance_type  = string
    volume_type    = string
    volume_size    = number
    iops           = optional(number)
    key_name       = string
    prevent_destroy = optional(bool, false)
  }))
}
