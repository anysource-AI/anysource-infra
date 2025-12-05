module "ecs" {
  source                            = "./modules/ecs"
  project                           = var.project
  environment                       = var.environment
  region                            = var.region
  vpc_id                            = local.vpc_id
  vpc_cidr                          = var.vpc_cidr
  enable_dual_alb                   = var.enable_dual_alb
  vpc_peering_connections           = var.vpc_peering_connections
  services_configurations           = var.services_configurations
  services_names                    = keys(var.services_configurations)
  ecr_repositories                  = local.ecr_repositories
  ecs_task_execution_role_arn       = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn                 = module.roles_micro_services.ecs_task_role_arn
  private_subnets                   = local.private_subnet_ids
  public_subnets                    = local.public_subnet_ids
  public_alb_security_group         = module.sg_alb
  public_alb_target_groups          = module.alb.target_groups
  internal_alb_target_groups        = var.enable_dual_alb ? module.alb_internal[0].target_groups : null
  prestart_container_cpu            = var.prestart_container_cpu
  prestart_container_memory         = var.prestart_container_memory
  prestart_timeout_seconds          = var.prestart_timeout_seconds
  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  enable_ecs_exec                   = var.enable_ecs_exec

  # Backend-specific environment variables (non-sensitive)
  backend_env_vars = local.backend_env_vars

  # Backend-specific secrets from AWS Secrets Manager
  backend_secret_vars = local.backend_secret_vars

  # Frontend-specific environment variables (non-sensitive)
  frontend_env_vars = local.frontend_env_vars

  depends_on = [module.iam, module.sg_alb, module.alb, aws_secretsmanager_secret_version.app_secrets, aws_bedrock_guardrail.guardrail]
}
