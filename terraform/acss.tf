resource "aws_appautoscaling_target" "target" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.logo_ecs_cluster.name}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "scale_down" {
  name               = "scale-down"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.target.resource_id
  scalable_dimension = aws_appautoscaling_target.target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}
resource "aws_appautoscaling_policy" "scale_up" {
  name               = "scale-up"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.target.resource_id
  scalable_dimension = aws_appautoscaling_target.target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "scale-down-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = "20"
  alarm_description   = "Low cpu utilization alarm"
  alarm_actions       = [aws_appautoscaling_policy.scale_down.arn]

  metric_query {
    id          = "e1"
    expression  = "SELECT AVG(CPUUtilization)FROM SCHEMA(\"AWS/ECS\", ClusterName,ServiceName)"
    label       = "CPUUtilization (Expected)"
    return_data = "true"
    period      = "60"

  }

}

resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "scale-up-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = "50"
  alarm_description   = "High cpu utilization alarm"
  alarm_actions       = [aws_appautoscaling_policy.scale_up.arn]

  metric_query {
    id          = "e1"
    expression  = "SELECT AVG(CPUUtilization)FROM SCHEMA(\"AWS/ECS\", ClusterName,ServiceName)"
    label       = "CPUUtilization (Expected)"
    return_data = "true"
    period      = "60"
  }
}








