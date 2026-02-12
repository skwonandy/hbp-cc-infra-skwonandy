variable "env" { type = string }
variable "project_name" {
  type    = string
  default = "hbp-cc"
}
variable "domain_name" {
  type        = string
  description = "証明書のドメイン（例: example.com）。ワイルドカード *.domain_name も SAN に含む"
}
variable "zone_id" {
  type        = string
  description = "Route53 ホストゾーン ID（DNS 検証用 CNAME を作成するゾーン）"
}
variable "tags" {
  type    = map(string)
  default = {}
}
