### network load balancer (bastion host용)

resource "aws_lb" "bastionhost-network-loadbalancer" {
  name                             = "bastionhost-network-loadbalancer"
  internal                         = false                                                                                                # internet-facing 설정
  load_balancer_type               = "network"                                                                                            # load_balancer type 설정 (network)
  subnets                          = [module.global-shop-project-vpc.public_subnets[0], module.global-shop-project-vpc.public_subnets[1]] # public subnet 설정 (192.168.56.0/27, 192.168.56.32/27)       
  enable_cross_zone_load_balancing = true                                                                                                 # 영역 간 로드밸런싱 활성화
}

### network load balancer target group 생성 (bastion host용)
resource "aws_lb_target_group" "bastionhost-network-targetgroup" {
  name     = "bastionhost-network-targetgroup"
  port     = 22    # port 설정 (22)
  protocol = "TCP" # protocol 설정 (TCP)
  vpc_id   = module.global-shop-project-vpc.vpc_id
}

### network load balancer listener 설정
resource "aws_lb_listener" "bastionhost-nlb-listener" {
  load_balancer_arn = aws_lb.bastionhost-network-loadbalancer.arn # network load_balancer 연결
  port              = 22                                          # port 설정 (22)
  protocol          = "TCP"                                       # protocol 설정 (TCP)

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bastionhost-network-targetgroup.arn # network load_balancer target group 연결
  }
}




### application load balancer

resource "aws_lb" "application-loadbalancer" {
  name                             = "application-loadbalancer"
  internal                         = false                                                                                                # internet-facing 설정
  load_balancer_type               = "application"                                                                                        # load_balancer type 설정 (application)
  security_groups                  = [aws_security_group.all-sg.id]                                                                       # security group 설정 (nlb는 설정하지 않음)
  subnets                          = [module.global-shop-project-vpc.public_subnets[0], module.global-shop-project-vpc.public_subnets[1]] # public subnet 설정 (192.168.56.0/27, 192.168.56.32/27)       
  enable_cross_zone_load_balancing = true                                                                                                 # 영역 간 로드밸런싱 활성화
}

### application load balancer target group 생성 (workernode 용)
resource "aws_lb_target_group" "application-targetgroup" {
  name     = "application-targetgroup"
  port     = 80     # port 설정 (80)
  protocol = "HTTP" # protocol 설정 (HTTP)
  vpc_id   = module.global-shop-project-vpc.vpc_id

  stickiness {
    type            = "lb_cookie" # sticky session 설정 -> load_balancer type (application 자체 쿠키를 가지고 있지 않은 경우)
    enabled         = true        # stickiness 활성화 (default 값 = true, 비활성 시 =  stickiness)
    cookie_duration = 86400       # lb_cookie type 에서만 설정가능 (1 day = 86400 seconds , 1 week = 604800 seconds)
  }
}


### 현재 사용 안함 (lb_cookie 사용 중)
#  stickiness {
#    type = "app_cookie"                                                             # sticky session 설정 -> application type (application 자체 쿠키를 가지고 있을 경우)
#    enabled = true                                                                  # stickiness 활성화 (default 값 = true, 비활성 시 =  stickiness)
#
#    app_cookie {
#      cookie_name = "Cookie"                                                        # app_cookie type 에서만 설정가능 (AWSALB, AWSALBAPP 및 AWSALBTG 접두사는 예약되어 있어 사용이 불가)
#    }
#  }
#}

### application load balancer listener 설정
resource "aws_lb_listener" "application-listener" {
  load_balancer_arn = aws_lb.application-loadbalancer.arn # application load_balancer 연결
  port              = 80                                  # port 설정 (80)
  protocol          = "HTTP"                              # protocol 설정 (HTTP)

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application-targetgroup.arn # application load_balancer target group 연결
  }
}

  

### auto scaling attachment  bastion + workernode

resource "aws_autoscaling_attachment" "bastion-autoscaling-attachment" {
  autoscaling_group_name = aws_autoscaling_group.bastion-asg.id # autoscaling group & network load_balancer target group attachment
  alb_target_group_arn   = aws_lb_target_group.bastionhost-network-targetgroup.arn
}

resource "aws_autoscaling_attachment" "workernode-autoscaling-attachment" {
  autoscaling_group_name = aws_autoscaling_group.workernode-asg.id # autoscaling group & application load_balancer target group attachment
  alb_target_group_arn   = aws_lb_target_group.application-targetgroup.arn
}
