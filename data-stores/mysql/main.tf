provider "aws" {
    region = "${var.region}"
  }

resource "aws_db_instance" "mysqldb" {
    engine		= "mysql"
    allocated_storage	= 10
    instance_class	= "db.t2.micro"
    name		= "mysqldb"
    username		= "admin"
    password		= "${var.db_password}"
    skip_final_snapshot  = true
  }
