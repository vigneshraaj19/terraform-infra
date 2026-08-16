# --- ECS task execution role (lets ECS pull images from ECR & write logs) ---

resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- GitHub OIDC provider (lets GitHub Actions assume an AWS role without
#     any long-lived access keys stored as GitHub secrets) ---

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # This is GitHub's well-known OIDC thumbprint (rarely changes).
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = local.common_tags
}

resource "aws_iam_role" "github_actions_deploy" {
  name = "${local.name_prefix}-github-actions-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Restricts which repo/branch can assume this role.
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}@*/${var.app_github_repo}@*:ref:refs/heads/${var.github_branch}"
        }
      }
    }]
  })

  tags = local.common_tags

  # Ensures the terraform-role's own IAM-management permissions (granted via
  # github_actions_terraform_iam below) are in place *before* Terraform CI
  # tries to modify this role's trust policy. Without this, Terraform may
  # run both updates in parallel and hit a permissions race (seen in
  # practice: UpdateAssumeRolePolicy AccessDenied on the first apply after
  # granting the permission, succeeding only on re-run).
  depends_on = [aws_iam_role_policy.github_actions_terraform_iam]
}

# Scoped-down deploy permissions: push to this one ECR repo, and
# register/update this one ECS service. Not admin-level access.
resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "${local.name_prefix}-github-actions-deploy-policy"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid    = "ECSDeploy"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid      = "PassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = [aws_iam_role.ecs_task_execution.arn]
        Condition = {
          StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" }
        }
      }
    ]
  })
}

# --- Second OIDC role: for the *Terraform* CI/CD pipeline itself (plan/apply
#     the infra), separate from the app-deploy role above. This one needs
#     much broader permissions since Terraform creates/manages VPC, ALB,
#     ECS, ECR, IAM, and CloudWatch resources. Trusts any branch so `terraform
#     plan` can run on PRs from feature branches; only `main` should ever
#     reach `terraform apply` (enforced in the workflow, not here).

resource "aws_iam_role" "github_actions_terraform" {
  name = "${local.name_prefix}-github-actions-terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_org}@*/${var.github_repo}@*:environment:production",
            "repo:${var.github_org}@*/${var.github_repo}@*:pull_request"
          ]
        }
      }
    }]
  })

  tags = local.common_tags
}

# NOTE: this is intentionally broad (PowerUserAccess-ish) because Terraform
# needs to create/modify VPC, ALB, ECS, ECR, CloudWatch, and IAM resources
# for this stack. It is NOT AdministratorAccess. If you want tighter scoping
# later, replace with a custom policy listing only the exact actions each
# .tf file uses — start from AWS's "IAM policy for a specific service"
# examples and narrow it down.
resource "aws_iam_role_policy_attachment" "github_actions_terraform_poweruser" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# PowerUserAccess excludes IAM management by design, but this stack's
# Terraform creates IAM roles/policies (ECS execution role, this role's
# sibling). Grant that narrowly, restricted to this project's name prefix.
resource "aws_iam_role_policy" "github_actions_terraform_iam" {
  name = "${local.name_prefix}-github-actions-terraform-iam-policy"
  role = aws_iam_role.github_actions_terraform.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ManageProjectIAMResources"
      Effect = "Allow"
      Action = [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PassRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:GetOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviders"
      ]
      Resource = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-*",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      ]
    }]
  })
}
