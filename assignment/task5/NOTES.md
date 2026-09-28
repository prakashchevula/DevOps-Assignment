The Provided snippet is meant to let **roleB** (Account A) assume **roleC** (Account B) and use one S3 bucket. 

It had **two separate bugs**: 
1. The trust policy
2. The permissions policy

---

## Bug 1 — trust policy: `user/roleB` instead of `role/roleB`



In Task 3, roleB is a **role**, not a user. There is no user called `roleB`.


---

## Bug 2 — permissions policy: `s3:*` on `Resource = "*"`

Original:

```hcl
Action   = "s3:*"
Resource = "*"
```

That is **every S3 action on every bucket and object in Account B** (and, with some S3 APIs, account-level calls too): read, write, delete, change bucket policy, wipe data.

Task 3 said roleC gets **full access to a single named S3 bucket** — not the account.

`Action = "s3:*"` on that one bucket is what “full access” means. The bug is the **resource**, not the action.

## After the fix

```
roleB (Account A)  --sts:AssumeRole-->  roleC (Account B)  --s3:*-->  bucket app-data only
```
