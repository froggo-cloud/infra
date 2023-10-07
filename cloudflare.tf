data "cloudflare_zone" "froggo_cloud" {
  name = "froggo.cloud"
}

resource "cloudflare_record" "froggo_cloud" {
  for_each = local.environments

  zone_id = data.cloudflare_zone.froggo_cloud.id
  name    = each.key == "dev" ? each.key : "froggo.cloud"
  type    = "A"
  value   = aws_instance.website[each.key].public_ip
  proxied = true
}
