output "elb_dns_name" {
  value = "${aws_elb.myalb.dns_name}"
}

output "asg_name" {
  value = "${aws_autoscaling_group.asg.name}"
}

output "elb_security_group_id" {
  value = "${aws_security_group.alb_sg.id}"
}
