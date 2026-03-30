resource "aws_security_group" "k8s" {
  name        = "${var.name_prefix}-k8s-sg"
  description = "Security group for all Kubernetes cluster nodes"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-k8s-sg"
  }
}

# ─── Inbound rules ─────────────────────────────────────────────────────────────

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.k8s.id
  description       = "SSH access"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "api_server" {
  security_group_id = aws_security_group.k8s.id
  description       = "Kubernetes API server"
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "etcd" {
  security_group_id            = aws_security_group.k8s.id
  description                  = "etcd server client API (internal)"
  from_port                    = 2379
  to_port                      = 2380
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s.id
}

resource "aws_vpc_security_group_ingress_rule" "kubelet" {
  security_group_id            = aws_security_group.k8s.id
  description                  = "kubelet API (internal)"
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s.id
}

resource "aws_vpc_security_group_ingress_rule" "kube_scheduler" {
  security_group_id            = aws_security_group.k8s.id
  description                  = "kube-scheduler (internal)"
  from_port                    = 10259
  to_port                      = 10259
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s.id
}

resource "aws_vpc_security_group_ingress_rule" "kube_controller" {
  security_group_id            = aws_security_group.k8s.id
  description                  = "kube-controller-manager (internal)"
  from_port                    = 10257
  to_port                      = 10257
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s.id
}

resource "aws_vpc_security_group_ingress_rule" "nodeport" {
  security_group_id = aws_security_group.k8s.id
  description       = "NodePort services"
  from_port         = 30000
  to_port           = 32767
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "internal_all" {
  security_group_id            = aws_security_group.k8s.id
  description                  = "All traffic between cluster nodes (Cilium overlay)"
  from_port                    = -1
  to_port                      = -1
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.k8s.id
}

# ─── Outbound rules ────────────────────────────────────────────────────────────

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.k8s.id
  description       = "Allow all outbound traffic"
  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
