# Task 4 — Least-privilege policy for `ci`

Policy file: `ci-policy.json`. Attach it to the **ci** user from Task 3 (Account A `000000000000`).

Policy only covers three jobs:

1. `docker push` to one ECR repo: `app`
2. Register a new task definition family app and point one ECS service at it: cluster `app`, service `app`
3. Read objects in one S3 bucket: `ci-build-artifacts`

---

## What the policy allows (and why each statement exists)


 `EcrGetAuthorizationToken` EcrGetAuthorizationToken — “Let me log in to ECR.”

docker login asks AWS for a short password. That API is account-wide. You cannot write “only for repo app” here; AWS rejects a repo ARN. So Resource is *. That does not mean it can push anywhere. It only means “may request a login token.” Push is a later statement.

`EcrPushOneRepository` “Upload the image, but only into repo app.”

docker push is not one API. It checks which layers already exist, uploads new ones, then calls PutImage (the tag, e.g. app:latest). If layers are already there, it reuses them (BatchGetImage, GetDownloadUrlForLayer) instead of uploading again.

The ARN is only repository/app. Same login token cannot push to some other repo, because those push APIs are not allowed there.

 
 `EcsRegisterTaskDefinition` “Register a new version of the app’s ”

A task definition is the JSON recipe: image URL, CPU, memory, which IAM roles the container uses. “Deploy a new task definition” means save a new revision of that recipe.


 `EcsDescribeTaskDefinition` “Read back the recipe I just saved.”

The pipeline usually asks “what revision number did I get?” That is describe. This one is locked to family app (task-definition/app:*).


`EcsDescribeOneCluster` “Look at this one cluster.”

Some deploy scripts call DescribeClusters (is the cluster active?). Allowed only for cluster app, not the whole account. 

`S3ListBuildArtifacts`  “List filenames in the artifacts bucket.”

Like ls on the bucket. ListBucket applies to the bucket, not a file, so the resource is arn:aws:s3:::ci-build-artifacts with no /*. That is why it is a separate statement from download.

 `S3ReadBuildArtifacts` | `GetObject` / `GetObjectVersion` on objects.


