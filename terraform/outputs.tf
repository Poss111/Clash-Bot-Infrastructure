output "public_subnet_one" {
  value       = aws_subnet.public_1.id
  description = "The subnets created in the VPC"
}

output "public_subnet_two" {
  value       = aws_subnet.public_2.id
  description = "The subnets created in the VPC"
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the VPC"
}

output "eip" {
  value       = aws_eip.nat_1.public_ip
  description = "The public IP address of the NAT gateway"
}

output "eip2" {
  value       = aws_eip.nat_2.public_ip
  description = "The public IP address of the NAT gateway"
}

