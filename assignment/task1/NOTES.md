# Task 1 notes

## How the 5 instances are driven

All five machines come from **one variable**: `var.instances` (a map). `for_each` creates them. There are not five copy-pasted `resource "aws_instance"` blocks with hardcoded types.

`lifecycle.prevent_destroy` cannot use a variable (Terraform requires a literal `true`/`false`). So the map is split:

- `aws_instance.regular` — instances with `prevent_destroy = false`
- `aws_instance.protected` — instances with `prevent_destroy = true` (here: **db-primary**)

Still one input; still not five hardcoded resources.

## io1 / io2

**db-primary** uses **io2** (100 GB, 3000 IOPS). `iops` is set only when volume type is `io1` or `io2`.

## Which instance cannot be deleted, and why

**db-primary** has `lifecycle { prevent_destroy = true }`.

Why this one: it is the data node (largest disk, provisioned IOPS). Destroying it by accident loses data and takes the longest to rebuild. A `terraform destroy` or a plan that replaces that instance will **fail** until someone removes the lifecycle flag on purpose.

## Outputs

- `instance_ids` — `{ web-a = "i-...", db-primary = "i-...", ... }`
- `private_ips` — `{ web-a = "10.x.x.x", ... }`

## Before apply

Key pairs in `terraform.tfvars` (`web-a-key`, `db-primary-key`, …) must already exist in the account/region, and `ami_id` must be a real AMI for that region.
