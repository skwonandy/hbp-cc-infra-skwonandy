# ACM モジュール

ALB および CloudFront 用 TLS 証明書。DNS 検証。

## plan/apply 時の ACM 証明書

検証用 Route53 レコードの `for_each` は証明書の `domain_validation_options` に依存するため、**証明書がまだ無い状態では plan がエラー**になる。`make plan` / `make apply` には `apply-acm-cert`（証明書のみ先に apply）が統合されているため、**初回から `make plan` / `make apply` だけでよい**。内部で証明書を先に作成してから plan/apply が実行される。


名前は末尾のドットあり・なしどちらでも可。証明書の `domain_validation_options[].resource_record_name` の値（例: `_xxxxxxxx.domain.com.`）を指定する。指定した名前は新規作成せず、検証時にはその FQDN を利用する。指定していない検証用 CNAME は従来どおり自動作成する。

## 新規作成レコードを Terraform 管理に取り込みたい場合（import）

既存の CNAME をこのモジュールの `aws_route53_record.validation` として管理したい場合は、import する。

```bash
# 例: envs/dev で実行。RECORD_NAME は Route53 の CNAME 名
terraform -chdir=envs/dev import 'module.acm[0].aws_route53_record.validation["RECORD_NAME"]' ZONE_ID_RECORD_NAME_CNAME
```
