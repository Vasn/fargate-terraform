output "public_subnet_1a_route_table_id" {
  value = aws_route_table.public_subnet_1a.id
}

output "public_subnet_1b_route_table_id" {
  value = aws_route_table.public_subnet_1b.id
}

output "private_subnet_1a_route_table_id" {
  value = aws_route_table.private_subnet_1a.id
}

output "private_subnet_1b_route_table_id" {
  value = aws_route_table.private_subnet_1b.id
}

output "private_data_route_table_id" {
  value = aws_route_table.private_data_subnet.id
}