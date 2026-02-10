# ElastiCache モジュール

Redis クラスタ。サブネットグループ・SG（ECS からのみ）を定義する。

## 入力

- env, project_name, vpc_id, private_subnet_ids, allowed_security_group_ids
- node_type, num_cache_nodes

## 出力

- redis_endpoint, redis_security_group_id
