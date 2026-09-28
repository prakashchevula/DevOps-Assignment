# Task 2 — Remote state and locking

## What happens today with local state (`terraform.tfstate` on disk)

State lives in a file on whoever ran `apply`. If two people run `terraform apply` at the same time:

1. Both read the same (or each their own copy of) state.
2. Both plan against that snapshot (e.g. “create 5 EC2s”).
3. Both write state when they finish.

There is **no lock**. Last write wins. Typical damage:

- Two sets of instances created, but state only records one set (orphans / extra cost).
- Person B overwrites Person A’s state and Terraform “forgets” resources A created.
- Partial apply + clobbered state → drift, failed destroys, production surprises.

Local state also cannot be shared safely (USB, Slack, git of `terraform.tfstate`).

## How S3 + DynamoDB stops that

**S3** holds the one shared `terraform.tfstate` (`key = task1/terraform.tfstate`). Versioning keeps history if a write goes badly.

**DynamoDB** table (`LockID` partition key) is Terraform’s lock:

1. `apply` / `plan` (with lock) writes a lock item first.
2. Second person gets **Error acquiring the state lock** until the first run finishes and deletes the lock.
3. Only then can the second run read the **updated** state and plan against reality.

`encrypt = true` encrypts the object in S3.

## Why bucket + table are in this file but init can still fail

The `backend "s3"` block is read at **`terraform init`**, before any resource exists. The bucket/table must already exist.

First-time order:

1. Comment out the `terraform { backend "s3" { ... } }` block in `task2.tf`.
2. `terraform init && terraform apply` — creates the bucket, versioning, encryption, public-access block, and DynamoDB table (local state).
3. Uncomment the backend block.
4. `terraform init -migrate-state` — copies local state into S3 and starts using the lock table.

After that, everyone uses the same state; concurrent applies serialize on DynamoDB.

## Resources

| Resource | Purpose |
|---|---|
| `aws_s3_bucket.tfstate` | Remote state file |
| versioning | Recover overwritten state |
| SSE AES256 | Encrypt state at rest |
| public access block | State is not public |
| `aws_dynamodb_table.tfstate_lock` | `LockID` lock |

Rename the bucket if `tfstate-devops-assignment-pchevula` is taken (S3 names are global). Keep the **same string** in the backend block and in `aws_s3_bucket`.
