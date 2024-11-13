terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket         = "sample-bucket-durian"
    key            = "terraform/state/asg"
    region         = "ap-southeast-1"
    encrypt        = true
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_launch_configuration" "asg_lc" {
  name_prefix          = "example-lc-"
  image_id             = "ami-047126e50991d067b"
  instance_type        = "t2.medium"
  security_groups      = ["sg-07e99f097f7b9f4a5"]
  key_name             = "local-mac"
  enable_monitoring    = true

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<-EOF
              #!/bin/bash
              yum install -y amazon-cloudwatch-agent
              cat <<EOT >> /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
              {
                "metrics": {
                  "append_dimensions": {
                    "InstanceId": "$${aws:InstanceId}"
                  },
                  "metrics_collected": {
                    "mem": {
                      "measurement": [
                        "mem_used_percent"
                      ],
                      "metrics_collection_interval": 60
                    },
                    "disk": {
                      "measurement": [
                        "used_percent"
                      ],
                      "metrics_collection_interval": 60
                    }
                  }
                }
              }
              EOT
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a start
  EOF
}


resource "aws_autoscaling_group" "asg" {
  desired_capacity     = 2
  max_size             = 5
  min_size             = 2
  launch_configuration = aws_launch_configuration.asg_lc.id
  vpc_zone_identifier  = ["subnet-0508c94155d2a08c8"]

  tag {
    key                 = "Name"
    value               = "example-asg-instance"
    propagate_at_launch = true
  }
}


resource "aws_autoscaling_policy" "cpu_scale_up" {
  name                   = "cpu-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name

  policy_type = "SimpleScaling"

  metric_aggregation_type = "Average"

}


resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "HighCPUAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 45
  alarm_actions       = [aws_autoscaling_policy.cpu_scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}
