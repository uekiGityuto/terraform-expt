output "vpc_id" {
  value = aws_vpc.default.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.publics : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.privates : s.id]
}
