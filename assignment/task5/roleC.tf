# Task 5 — fixed snippet
# Lets roleB (Account A 000000000000) assume roleC (Account B) with access
# to one named bucket only.

data "aws_iam_policy_document" "roleC_trust" {
  statement {
    sid     = "TrustRoleBOnly"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      # Bug 1 fix: roleB is a ROLE, not a user.
      identifiers = ["arn:aws:iam::000000000000:role/roleB"]
    }
  }
}

resource "aws_iam_role" "roleC" {
  name               = "roleC"
  assume_role_policy = data.aws_iam_policy_document.roleC_trust.json
}

resource "aws_iam_role_policy" "roleC_s3" {
  name = "roleC-s3-access"
  role = aws_iam_role.roleC.id

  # Bug 2 fix: s3:* on Resource "*" is every bucket in Account B.
  # Task 3: full access to one named bucket (bucket + objects).
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "FullAccessToNamedBucket"
      Effect = "Allow"
      Action = "s3:*"
      Resource = [
        "arn:aws:s3:::app-data",
        "arn:aws:s3:::app-data/*",
      ]
    }]
  })
}
