# RDS モジュール

PostgreSQL 17 の RDS インスタンス。ストレージ暗号化・サブネットグループ・SG（ECS からのみ許可）を定義する。

## 入力

- env, project_name, vpc_id, private_subnet_ids, allowed_security_group_ids
- instance_class, allocated_storage_gb, multi_az
- db_password (sensitive)

## 出力

- db_instance_endpoint, db_instance_address, rds_security_group_id
