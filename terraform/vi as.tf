### bastion host autoscaling, image_id= install mysql on bastion host

resource "aws_launch_template" "bastion-launch-template" {
  depends_on = [
    module.global-shop-project-vpc.public_subnets # 명시적 의존성 부여, public subnet 생성 후 생성
  ]

  name                                 = "bastion-launch-template"
  description                          = "bastion for Auto Scaling"
  instance_type                        = "t2.micro"                                    # instance type 설정 (t2.micro)
  image_id                             = "ami-0ea5eb4b05645aa8a"                       # image_id 설정 (mysql이 설치 된 bastion host image 만들어야함(변경예정))
  instance_initiated_shutdown_behavior = "terminate"                                   # image shutdown 시 terminate 활성화
  key_name                             = aws_key_pair.global-shop-project-key.key_name # key pair 설정

  network_interfaces {
    associate_public_ip_address = true                           # autoscaling network interfaces 설정
    security_groups             = [aws_security_group.all-sg.id] # security group 설정 (변경 예정)
  }

  monitoring {
    enabled = true # monitoring 활성화
  }

  placement {
    availability_zone = "ap-northeast-2" # availability zone 설정 (ap-northeast-2)
  }

  tags = {
    Name = "bastion-launch-template"
  }

  tag_specifications {
    resource_type = "instance" # autoscaling으로 생성된 instance의 이름 설정
    tags = {
      Name = "bastion_host_autoscaling"
    }
  }

}


### bastion autoscaling group 생성
resource "aws_autoscaling_group" "bastion-asg" {
  launch_template {
    id      = aws_launch_template.bastion-launch-template.id             # 시작 템플릿 연결
    version = aws_launch_template.bastion-launch-template.latest_version # 시작 템플릿 버전 지정
  }

  name             = "bastion-asg"
  desired_capacity = 2 # 원하는 용량 (2)
  min_size         = 2 # 최소 용량 (2)
  max_size         = 4 # 최대 용량 (4)

  health_check_type         = "ELB"                                                                                                # health check type (ELB)
  health_check_grace_period = 300                                                                                                  # health check grace period (300)
  force_delete              = true                                                                                                 # 삭제 활성화
  vpc_zone_identifier       = [module.global-shop-project-vpc.public_subnets[0], module.global-shop-project-vpc.public_subnets[1]] # public subnet 설정(192.168.56.0/27, 192.168.56.32/27)


}

### autoscaling policy 생성
resource "aws_autoscaling_policy" "bastion-target-tracking-configuration" {
  name                   = "bastion-target-tracking-configuration"
  autoscaling_group_name = aws_autoscaling_group.bastion-asg.name # autoscaling group 연결
  policy_type            = "TargetTrackingScaling"                # policy type 대상추적크기조정 설정
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization" # predefined metric type 설정 (CPU 사용률)
    }

    target_value = 50.0 # target value (50)
  }
}

# worker node autoscaling

resource "aws_launch_template" "workernode-launch-template" {
  depends_on = [
    module.global-shop-project-vpc.private_subnets
  ]

  name                                 = "workernode-launch-template"
  description                          = "worker node for Auto Scaling"
  instance_type                        = "t2.medium"                                   # instance type 설정 (t2.medium)
  image_id                             = "ami-0ea5eb4b05645aa8a"                       # image_id 설정 (k8s cluster 설치 전 image 사용)
  instance_initiated_shutdown_behavior = "terminate"                                   # image shutdown 시 terminate 활성화
  key_name                             = aws_key_pair.global-shop-project-key.key_name # key pair 설정

  network_interfaces {
    associate_public_ip_address = true                           # autoscaling network interfaces 설정
    security_groups             = [aws_security_group.all-sg.id] # security group 설정 (변경 예정)
  }

  monitoring {
    enabled = true # monitoring 활성화
  }

  placement {
    availability_zone = "ap-northeast-2" # availability zone 설정 (ap-northeast-2)
  }

  tags = {
    Name = "workernode-launch-template"
  }

  tag_specifications {
    resource_type = "instance" # autoscaling으로 생성된 instance의 이름 설정
    tags = {
      Name = "workernode_host_autoscaling"
    }
  }

}


### workernode autoscaling group 생성
resource "aws_autoscaling_group" "workernode-asg" {
  launch_template {
    id      = aws_launch_template.workernode-launch-template.id             # 시작 템플릿 연결
    version = aws_launch_template.workernode-launch-template.latest_version # 시작 템플릿 버전 지정
  }

  name             = "workernode-asg"
  desired_capacity = 4 # 원하는 용량 (4)
  min_size         = 4 # 최소 용량 (4)
  max_size         = 8 # 최대 용량 (8)

  health_check_type         = "ELB"                                                                                                  # health check type (ELB)
  health_check_grace_period = 300                                                                                                    # health check grace period (300)
  force_delete              = true                                                                                                   # 삭제 활성화
  vpc_zone_identifier       = [module.global-shop-project-vpc.private_subnets[0], module.global-shop-project-vpc.private_subnets[1]] # private subnet설정 (192.168.56.128/28, 192.168.56.144/28)

}

### workernode autoscaling policy 생성
resource "aws_autoscaling_policy" "workernode-target-tracking-configuration" {
  name                   = "workernode-target-tracking-configuration"
  autoscaling_group_name = aws_autoscaling_group.workernode-asg.name # autoscaling group 연결
  policy_type            = "TargetTrackingScaling"                   # policy type 대상추적크기조정 설정
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization" # predefined metric type 설정 (CPU 사용률)
    }

    target_value = 50.0 # target value (50)
  }
}
