output "app_instance_public_ip_addr" {
  value = { for instance in aws_instance.website : instance.tags["Name"] => aws_eip.website[instance.tags["Env"]].public_ip }
}

output "app_domains" {
  value = { for record in cloudflare_record.froggo_cloud : record.hostname => record.value }
}