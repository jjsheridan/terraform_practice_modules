output "address" {
    value = "${aws_db_instance.mysqldb.address}"
  }

output "port" {
    value = "${aws_db_instance.mysqldb.port}"
  }
