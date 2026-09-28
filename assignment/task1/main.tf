locals {
  # Split so lifecycle.prevent_destroy can be a literal on one resource.
  # lifecycle values cannot be dynamic in Terraform.
  regular   = { for name, cfg in var.instances : name => cfg if !cfg.prevent_destroy }
  protected = { for name, cfg in var.instances : name => cfg if cfg.prevent_destroy }
}

resource "aws_instance" "regular" {
  for_each = local.regular

  ami           = var.ami_id
  instance_type = each.value.instance_type
  key_name      = each.value.key_name

  root_block_device {
    volume_type = each.value.volume_type
    volume_size = each.value.volume_size
    iops        = contains(["io1", "io2"], each.value.volume_type) ? each.value.iops : null
    encrypted   = true
  }

  tags = {
    Name        = each.key
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_instance" "protected" {
  for_each = local.protected

  ami           = var.ami_id
  instance_type = each.value.instance_type
  key_name      = each.value.key_name

  root_block_device {
    volume_type = each.value.volume_type
    volume_size = each.value.volume_size
    iops        = contains(["io1", "io2"], each.value.volume_type) ? each.value.iops : null
    encrypted   = true
  }

  tags = {
    Name        = each.key
    Environment = var.environment
    Owner       = var.owner
  }

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  all_instances = merge(aws_instance.regular, aws_instance.protected)
}
