# Task 3 — Multi-Account IAM & Cross-Account Access

Account A = `000000000000`. Account B = `111111111111`.
Named S3 bucket in Account B: `app-data` (example name).

```
Account A
  group1 (CLI only):     engine, ci   →  may assume roleB
  group2 (console+CLI):  alice, bob   →  may assume roleA
  roleA  = admin on all AWS services except IAM
  roleB  = only permission: sts:AssumeRole on roleC in Account B

Account B
  roleC  = s3:* on bucket app-data only
           trust: roleB from Account A — not Account A root, not any other A principal
```

---

## Account A

### group1 — CLI / programmatic only

Members: **engine**, **ci**.

- Create IAM users, add to group1.
- Do **not** create a console password (no login profile).
- Attach a Deny so they cannot enable console themselves:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyConsoleLogin",
      "Effect": "Deny",
      "Action": [
        "iam:CreateLoginProfile",
        "iam:UpdateLoginProfile",
        "iam:ChangePassword"
      ],
      "Resource": "*"
    }
  ]
}
```

- Allow them only to assume roleB:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AssumeRoleB",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::000000000000:role/roleB"
    }
  ]
}
```

### group2 — full console + CLI

Members of my choice: **alice**, **bob**.

- Create IAM users, add to group2.
- Create console login profiles (password + MFA) so they can use the console; they can also use access keys / SSO-style CLI.
- Allow them to change their own password and to assume roleA:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowOwnPasswordChange",
      "Effect": "Allow",
      "Action": ["iam:ChangePassword", "iam:GetLoginProfile"],
      "Resource": "arn:aws:iam::000000000000:user/${aws:username}"
    },
    {
      "Sid": "AssumeRoleA",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::000000000000:role/roleA"
    }
  ]
}
```

### roleA — administrative access except IAM

**Trust:** Account A (so group2 can assume it; group1 is not granted `sts:AssumeRole` on this role).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::000000000000:root" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Permissions:** allow everything except IAM, and an explicit Deny on IAM so a later extra policy cannot open IAM back up.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AdminExceptIAM",
      "Effect": "Allow",
      "NotAction": "iam:*",
      "Resource": "*"
    },
    {
      "Sid": "ExplicitDenyIAM",
      "Effect": "Deny",
      "Action": "iam:*",
      "Resource": "*"
    }
  ]
}
```

### roleB — only assume roleC in Account B

**Trust:** only the group1 users (engine, ci), not alice/bob.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::000000000000:user/engine",
          "arn:aws:iam::000000000000:user/ci"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Permissions:** this is the entire policy — nothing else.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AssumeRoleCOnly",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::111111111111:role/roleC"
    }
  ]
}
```

---

## Account B

### roleC — full access to one named S3 bucket; assumable only by roleB

**Trust:** roleB’s ARN only. Not `arn:aws:iam::000000000000:root`.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TrustRoleBOnly",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::000000000000:role/roleB" },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Permissions:** `s3:*` on that bucket and its objects only — not `Resource: "*"`.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "FullAccessToNamedBucket",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::app-data",
        "arn:aws:s3:::app-data/*"
      ]
    }
  ]
}
```

Path: `engine`/`ci` → assume **roleB** (Account A) → assume **roleC** (Account B) → bucket `app-data`.
`alice`/`bob` cannot take that path; they assume **roleA** and stay in Account A.

---

## Would you actually give `engine` and `ci` IAM users with access keys in a real production setup, or would you do something different?

**No.** I would not give them long-lived IAM user access keys in production.

**`ci`** is a pipeline, not a person. Access keys get committed to git, pasted into logs, and are not rotated. Use a **role** and **short-lived** credentials:

- GitHub Actions / GitLab → OIDC → `sts:AssumeRoleWithWebIdentity`
- AWS CodeBuild / CodePipeline → the project’s own service role
- Jenkins on EC2 / ECS / EKS → instance profile, task role, or IRSA

That role then assumes **roleB** (or a dedicated CI role). No IAM user, no access key.

**`engine`** — if it is a human: **IAM Identity Center (SSO)**, MFA, temporary CLI credentials, then assume the role they need. If it is a workload: same pattern as CI (instance profile / IRSA / OIDC), not a user key.

IAM users + access keys only if a vendor cannot do OIDC. Then: one key in Secrets Manager, rotation, no console, CloudTrail on `AssumeRole`.

The assignment still *names* IAM users `engine` and `ci`; that is what I designed above. Production would replace those users with federated roles.

---

## In roleC’s trust policy, why does it matter whether you trust the whole Account A root vs roleB’s specific ARN?

`arn:aws:iam::000000000000:root` in a trust policy is **not** “the root user.” It means **any principal from Account A** (users, roles, SSO roles) that is also allowed to call `sts:AssumeRole` on roleC.

**If roleC trusts Account A root:**

- Anyone in A who is given `sts:AssumeRole` on roleC can walk into Account B (alice, a leaked `ci` key, a new admin user).
- Account A admins can grant themselves that permission **without Account B changing the trust policy**.
- Blast radius is the **whole of Account A**.

**If roleC trusts only `arn:aws:iam::000000000000:role/roleB`:**

- STS in Account B accepts the call **only** when the caller **is roleB**.
- `engine`, `ci`, `alice`, `bob` cannot assume roleC directly. Permissions they have **in Account A** (even `AdministratorAccess`) do not override Account B’s trust policy.
- To use the bucket they must: (1) be allowed to assume roleB, and (2) roleB then assumes roleC. roleB itself can do nothing except that assume.

That is least privilege on the **trust** side, not only on the S3 policy. roleC therefore trusts roleB’s ARN, not Account A root.
