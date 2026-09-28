aws_region  = "us-east-2"
environment = "assignment"
owner       = "prakash-chevula"

# Replace with a real AMI in us-east-2 before apply, e.g.:
# aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023*-x86_64" --query 'sort_by(Images,&CreationDate)[-1].ImageId'
ami_id = "ami-0c101f26f147fa7fd"

# Five instances, all different type / volume type / size / key pair.
# Key pairs must already exist in the account/region.
instances = {
  web-a = {
    instance_type   = "t3.micro"
    volume_type     = "gp3"
    volume_size     = 20
    key_name        = "web-a-key"
    prevent_destroy = false
  }
  web-b = {
    instance_type   = "t3.small"
    volume_type     = "gp2"
    volume_size     = 30
    key_name        = "web-b-key"
    prevent_destroy = false
  }
  app-a = {
    instance_type   = "t3.medium"
    volume_type     = "gp3"
    volume_size     = 40
    key_name        = "app-a-key"
    prevent_destroy = false
  }
  # Protected instance — see NOTES.md
  db-primary = {
    instance_type   = "m5.large"
    volume_type     = "io2"
    volume_size     = 100
    iops            = 3000
    key_name        = "db-primary-key"
    prevent_destroy = true
  }
  batch-a = {
    instance_type   = "c5.large"
    volume_type     = "st1"
    volume_size     = 125
    key_name        = "batch-a-key"
    prevent_destroy = false
  }
}
