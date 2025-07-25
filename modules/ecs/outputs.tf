output "aws_cloudwatch_log_group" {
  value = concat(
    [for log_group in aws_cloudwatch_log_group.ecs_cw_log_group : log_group.name],
    try([aws_cloudwatch_log_group.prestart_cw_log_group.name], [])
  )
}

output "aws_ecs_task_definition" {
  value = [for taskdef in aws_ecs_task_definition.ecs_task_definition : taskdef]
}