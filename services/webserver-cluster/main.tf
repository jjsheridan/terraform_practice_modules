data "aws_caller_identity" "current" {}

data "terraform_remote_state" "db" {
  backend = "s3"
    config {
    bucket = "${var.db_remote_state_bucket}"
    key    = "${var.db_remote_state_key}"
    region = "us-west-2"
    }
  }

data "template_file" "user_data" {
    template = "${file("${path.module}/user-data.sh")}"
      vars {
        server_port = "${var.port_num}"
        db_address  = "${data.terraform_remote_state.db.address}"
        db_port     = "${data.terraform_remote_state.db.port}"
        }
    }

resource "aws_launch_configuration" "alc" {
    image_id = "ami-a9d276c9"
    instance_type = "${var.instance_type}"
    key_name = "mykey"
    security_groups = ["${aws_security_group.ec2_sg.id}"]
    user_data = "${data.template_file.user_data.rendered}"

lifecycle {
    create_before_destroy = true
    }
  }

resource "aws_key_pair" "mykey" {
    key_name = "mykey"
    public_key = "${file("~/.ssh/mykey.pub")}"
  }

resource "aws_security_group" "ec2_sg" {
    name = "${var.cluster_name}-ec2_sg"

    lifecycle {
      create_before_destroy = true
      }

    depends_on = ["aws_security_group.alb_sg"]
  }

resource "aws_security_group_rule" "allow_8080_inbound" {
    type              = "ingress"
    security_group_id = "${aws_security_group.ec2_sg.id}"
    from_port         = "${var.port_num}"
    to_port           = "${var.port_num}"
    protocol          = "tcp"
    source_security_group_id   = "${aws_security_group.alb_sg.id}"
  }

resource "aws_security_group_rule" "allow_ssh_inbound" {
    type              = "ingress"
    security_group_id = "${aws_security_group.ec2_sg.id}"
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["70.181.196.36/32"]
    }

resource "aws_security_group" "alb_sg" {
    name = "${var.cluster_name}-alb_sg"

    lifecycle {
        create_before_destroy = true
      }
    }

resource "aws_security_group_rule" "allow_http_inbound" {
    security_group_id = "${aws_security_group.alb_sg.id}"
    type              = "ingress"
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    cidr_blocks       = ["70.181.196.36/32"]
  }

resource "aws_security_group_rule" "allow_all_outbound" {
    security_group_id = "${aws_security_group.alb_sg.id}"
    type              = "egress"
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
  }


data "aws_availability_zones" "all" {}

resource "aws_autoscaling_group" "asg" {
    launch_configuration = "${aws_launch_configuration.alc.id}"
    availability_zones   = ["${data.aws_availability_zones.all.names}"]

    load_balancers = ["${aws_elb.myalb.name}"]
    health_check_type = "ELB"
    min_size = "${var.min_size}"
    max_size = "${var.max_size}"

    tag {
      key = "Name"
      value = "${var.cluster_name}-ec2"
      propagate_at_launch = true
  }
}

resource "aws_elb" "myalb" {
    name = "${var.cluster_name}-myalb"
    availability_zones = ["${data.aws_availability_zones.all.names}"]
    security_groups =  ["${aws_security_group.alb_sg.id}"]

    listener {
      lb_port = 80
      lb_protocol = "http"
      instance_port = "${var.port_num}"
      instance_protocol = "http"
  }

    health_check {
      healthy_threshold = 2
      unhealthy_threshold = 2
      timeout = 3
      interval = 30
      target = "HTTP:${var.port_num}/"
  }
}
