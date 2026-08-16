output "alb_dns_name" {
  description = "Public URL of the app (once deployed)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "Push docker images here"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "github_actions_role_arn" {
  description = "For deploy.yml (app CI/CD) - AWS_GITHUB_ACTIONS_ROLE_ARN repo variable"
  value       = aws_iam_role.github_actions_deploy.arn
}

output "github_actions_terraform_role_arn" {
  description = "For terraform.yml (infra CI/CD) - AWS_GITHUB_ACTIONS_TERRAFORM_ROLE_ARN repo variable"
  value       = aws_iam_role.github_actions_terraform.arn
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.app.name
}
