# terraform-infra

Standalone infra repo. Provisions AWS VPC, ALB, ECS/Fargate cluster+service,
ECR repo, and the IAM/OIDC roles both this repo's and your React app repo's
GitHub Actions use to deploy — with no long-lived AWS keys stored anywhere.

This repo owns the infrastructure. It does **not** contain your React app
code — that lives in its own repo (see the `react-app-cicd` package / your
existing React repo).

## Layout
```
terraform-bootstrap/   # one-time: creates the S3 state bucket + lock table
terraform/               # the actual infra (VPC, ALB, ECS, ECR, IAM)
.github/workflows/terraform.yml   # plan on PR, apply on merge to main
```

## One-time setup

### 1. Bootstrap remote state (run locally)
```bash
cd terraform-bootstrap
terraform init
terraform apply -var="state_bucket_name=vignesh-terraform-state-2026"
```
Note the `state_bucket` output.

### 2. Configure variables
In `terraform/main.tf`, replace `REPLACE-WITH-YOUR-STATE-BUCKET-NAME` in the
`backend "s3"` block with your bucket name from step 1.

In `terraform/variables.tf` (or via `-var`), set:
- `github_org` — your GitHub username/org
- `github_repo` — the name of **this** terraform-infra repo (controls who
  can run `terraform plan`/`apply`)
- `app_github_repo` — the name of your **React app** repo (controls who can
  build/push/deploy the app — kept separate since it's a different repo)
- `aws_region` — if not us-east-1

### 3. First apply (run locally, with your AWS CLI credentials)
```bash
cd terraform
terraform init
terraform apply
```
This creates everything, including **two** IAM roles for GitHub Actions:
- one for this repo to run `terraform plan`/`apply`
- one for your React app repo to build/push/deploy

Note the outputs:
```bash
terraform output github_actions_terraform_role_arn   # for THIS repo
terraform output github_actions_role_arn              # for your REACT APP repo
terraform output ecr_repository_url
terraform output alb_dns_name
```

### 4. Wire this repo's GitHub Actions
In **this repo's** GitHub Settings → Secrets and variables → Actions →
Variables, add:
- `AWS_GITHUB_ACTIONS_TERRAFORM_ROLE_ARN` = the terraform role ARN

Also edit `.github/workflows/terraform.yml`, updating `TF_VAR_github_org`
and `TF_VAR_github_repo` near the top to match.

### 5. Give the role ARN to your React app repo
Copy the `github_actions_role_arn` output — you'll paste it into the
**react-app-cicd** repo's GitHub variables (see that repo's README).

## Day-to-day use
- Open a PR changing anything under `terraform/` → CI comments the plan
- Merge to `main` → CI applies automatically
- Everything else about the app (Docker build, ECS deploy) lives in the
  react-app-cicd repo, not here
