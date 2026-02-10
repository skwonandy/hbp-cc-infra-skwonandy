# VPC モジュール

## 用途

VPC とパブリック・プライベートサブネット、NAT Gateway、ルートテーブル、最小限のセキュリティグループを定義する。

## 入力 (variables)

| 名前 | 必須 | 説明 |
|------|------|------|
| env | ○ | 環境名 (sandbox, dev, stg, prod) |
| vpc_cidr | ○ | VPC の CIDR (例: 10.0.0.0/16) |
| az_count | ○ | 利用する AZ 数 (1 または 2) |
| project_name | - | リソース名のプレフィックス (default: hbp-cc) |
| tags | - | 追加タグ |

## 出力 (outputs)

| 名前 | 説明 |
|------|------|
| vpc_id | VPC ID |
| vpc_cidr | VPC の CIDR |
| public_subnet_ids | パブリックサブネット ID のリスト |
| private_subnet_ids | プライベートサブネット ID のリスト |
| azs | 利用している AZ 名のリスト |
| internal_security_group_id | VPC 内通信用 SG の ID |
