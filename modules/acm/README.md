# ACM モジュール

ALB および CloudFront 用 TLS 証明書。DNS 検証。

## 既存の Route53 検証レコードがある場合

証明書の DNS 検証用 CNAME がすでに Route53 に存在する場合は、**参照のみ**にする（Terraform でリソースを作らないため、`terraform destroy` してもそのレコードは削除されない）。

呼び出し元で `existing_validation_record_names` に既存レコードの名前（FQDN）を渡す。**import や state mv は不要**。`make init` → `make plan` → `make apply` だけでよい。

```hcl
module "acm" {
  source = "../../modules/acm"
  # ...
  existing_validation_record_names = ["_8b20608dc98bbd341afe22a806aeb9e9.skwondocs.com."]
}
```

名前は末尾のドットあり・なしどちらでも可。証明書の `domain_validation_options[].resource_record_name` の値（例: `_xxxxxxxx.domain.com.`）を指定する。指定した名前は新規作成せず、検証時にはその FQDN を利用する。指定していない検証用 CNAME は従来どおり自動作成する。

## 新規作成レコードを Terraform 管理に取り込みたい場合（import）

既存の CNAME をこのモジュールの `aws_route53_record.validation` として管理したい場合は、import する。

```bash
# 例: envs/dev で実行。RECORD_NAME は Route53 の CNAME 名
terraform -chdir=envs/dev import 'module.acm[0].aws_route53_record.validation["RECORD_NAME"]' ZONE_ID_RECORD_NAME_CNAME
```

Import ID は `ZONEID_RECORDNAME_TYPE`（アンダースコア区切り）。RECORDNAME に末尾のドットを含める場合は `ZONEID__xxxx.skwondocs.com._CNAME` のように ZONEID と RECORDNAME の間にアンダースコアが続く。
