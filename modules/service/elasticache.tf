# dev 전용 Valkey ElastiCache Serverless. 앱 연결 설정은 별도 요청으로 처리한다.
# Serverless는 노드 기반 클러스터보다 생성이 빠르고, 사용량 상한으로 데모 비용을 제한한다.
locals {
  elasticache_enabled = local.enabled * (var.environment == "dev" ? 1 : 0)
}

resource "aws_security_group" "elasticache" {
  count       = local.elasticache_enabled
  name        = "${local.name}-elasticache"
  description = "Valkey access from app EC2 only"
  vpc_id      = data.aws_vpc.foundation.id
  tags        = { Name = "${local.name}-elasticache" }
}

resource "aws_vpc_security_group_ingress_rule" "elasticache_from_ec2" {
  count                        = local.elasticache_enabled
  security_group_id            = aws_security_group.elasticache[0].id
  referenced_security_group_id = aws_security_group.ec2[0].id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "Valkey from app EC2"
}

resource "aws_vpc_security_group_egress_rule" "elasticache_all" {
  count             = local.elasticache_enabled
  security_group_id = aws_security_group.elasticache[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_elasticache_serverless_cache" "this" {
  count              = local.elasticache_enabled
  name               = "${local.name}-cache"
  engine             = "valkey"
  subnet_ids         = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.elasticache[0].id]

  cache_usage_limits {
    data_storage {
      minimum = 1
      maximum = 1
      unit    = "GB"
    }
    ecpu_per_second {
      minimum = 1000
      maximum = 1000
    }
  }

  tags = { Name = "${local.name}-cache" }
}

output "elasticache_endpoint" {
  value = try(aws_elasticache_serverless_cache.this[0].endpoint[0].address, null)
}
