variable "zone_id" {
  type        = string
  description = "既存 Route53 ホストゾーンの ID"
}
variable "tags" {
  type    = map(string)
  default = {}
}
