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
variable "existing_validation_record_names" {
  type        = set(string)
  default     = []
  description = "既に Route53 に存在する検証用 CNAME の名前（FQDN）。指定した名前は作成せず参照のみ。末尾のドットは有無どちらでも可。"
}
variable "tags" {
  type    = map(string)
  default = {}
}
