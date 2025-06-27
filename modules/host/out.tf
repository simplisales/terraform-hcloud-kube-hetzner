output "ipv4_address" {
  value = aws_instance.server.public_ip
}

output "ipv6_address" {
  value = aws_instance.server.ipv6_addresses[0]
}

output "private_ipv4_address" {
  value = aws_instance.server.private_ip
}

output "name" {
  value = aws_instance.server.tags["Name"]
}

output "id" {
  value = aws_instance.server.id
}

output "domain_assignments" {
  description = "Assignment of domain to the primary IP of the server"
  value       = []
}
