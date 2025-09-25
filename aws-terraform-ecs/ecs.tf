# Validation: Ensure all services have corresponding ECR repository URIs
locals {
  missing_ecr_services = [
    for svc in keys(var.services_configurations) : svc
    if !contains(keys(var.ecr_repositories), svc)
  ]

  # This will cause an error if any services are missing ECR URIs
  validate_ecr_completeness = length(local.missing_ecr_services) == 0 ? true : tobool("ERROR: Missing ECR repository URIs for services: ${join(", ", local.missing_ecr_services)}. All services must have explicit ECR URIs defined in ecr_repositories variable.")

  # Extract image tags from ECR repository URIs
  # ECR URIs format: account.dkr.ecr.region.amazonaws.com/repo:tag or public.ecr.aws/namespace/repo:tag
  backend_image_tag  = length(split(":", var.ecr_repositories["backend"])) > 1 ? reverse(split(":", var.ecr_repositories["backend"]))[0] : "latest"
  frontend_image_tag = length(split(":", var.ecr_repositories["frontend"])) > 1 ? reverse(split(":", var.ecr_repositories["frontend"]))[0] : "latest"
}

module "ecs" {
  source                            = "./modules/ecs"
  project                           = var.project
  environment                       = var.environment
  region                            = var.region
  vpc_id                            = module.vpc.vpc_id
  vpc_cidr                          = var.vpc_cidr
  services_configurations           = var.services_configurations
  services_names                    = keys(var.services_configurations)
  ecr_repositories                  = var.ecr_repositories
  ecs_task_execution_role_arn       = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn                 = module.roles_micro_services.ecs_task_role_arn
  private_subnets                   = module.vpc.private_subnets
  public_subnets                    = module.vpc.public_subnets
  public_alb_security_group         = module.sg_private_alb
  public_alb_target_groups          = module.private_alb.target_groups
  prestart_container_cpu            = var.prestart_container_cpu
  prestart_container_memory         = var.prestart_container_memory
  prestart_timeout_seconds          = var.prestart_timeout_seconds
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  # Backend-specific environment variables (non-sensitive)
  backend_env_vars = local.backend_env_vars

  # Backend-specific secrets from AWS Secrets Manager
  backend_secret_vars = local.backend_secret_vars

  # Frontend-specific environment variables (non-sensitive)
  frontend_env_vars = local.frontend_env_vars

  depends_on = [module.iam, module.vpc, module.sg_private_alb, module.private_alb, aws_secretsmanager_secret_version.app_secrets]
}
