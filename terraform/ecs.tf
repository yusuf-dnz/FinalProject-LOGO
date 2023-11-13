resource "aws_ecs_cluster" "logo_ecs_cluster" {
  name = "logo-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "web_page_task" {
  family                   = "web-page-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  container_definitions    = <<TASK_DEFINITION
[
  {
    "name": "react-app-container",
    "image": "ysfdnz/logo-project:latest",
    "cpu": 256,
    "memory": 512,
    "essential": true,
    "portMappings" : [
        {
          "containerPort" : 80,
          "hostPort"      : 80,
          "protocol"      :"tcp"
        }
      ]
  }
]
TASK_DEFINITION

}

resource "aws_lb_target_group" "load_balancer_tg" {
  name        = "load-balancer-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
  health_check {
    matcher             = "200"
    path                = "/"
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    timeout             = 20
    unhealthy_threshold = 3
    protocol            = "HTTP"
  }
}

resource "aws_lb_listener" "lb_http_listener" {
  load_balancer_arn = aws_lb.react_app_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.load_balancer_tg.arn
  }
}

resource "aws_lb" "react_app_lb" {
  name               = "react-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_security.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

}

resource "aws_ecs_service" "ecs_service" {
  name            = "ecs-service"
  cluster         = aws_ecs_cluster.logo_ecs_cluster.id
  task_definition = aws_ecs_task_definition.web_page_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [module.vpc.public_subnets[0], module.vpc.public_subnets[1], module.vpc.public_subnets[2]]
    security_groups  = [aws_security_group.default_sg.id]
    assign_public_ip = true
  }


  load_balancer {
    target_group_arn = aws_lb_target_group.load_balancer_tg.arn
    container_name   = "react-app-container"
    container_port   = 80
  }

}
