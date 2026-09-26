# Modulo Security Group — generico, serve para API, RDS, bastion ou qualquer
# outro papel. O que muda entre os usos e apenas a lista ingress_rules.

locals {
  sg_name = "${var.project_name}-${var.environment}-${var.name}"

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })

  # Achatar as regras por CIDR: uma regra com 2 CIDRs vira 2 recursos. A chave
  # combina porta e CIDR para ficar estavel — com indice numerico, inserir uma
  # regra no meio da lista recriaria todas as seguintes.
  cidr_rules = {
    for r in flatten([
      for regra in var.ingress_rules : [
        for cidr in coalesce(regra.cidr_blocks, []) : {
          key         = "${regra.protocol}-${regra.from_port}-${cidr}"
          description = regra.description
          from_port   = regra.from_port
          to_port     = regra.to_port
          protocol    = regra.protocol
          cidr        = cidr
        }
      ]
    ]) : r.key => r
  }

  # Duas armadilhas de for_each com valor que so existe depois do apply — o
  # source_security_group_id e o ID de OUTRO Security Group:
  #
  # 1. A CHAVE nao pode conter esse ID. Aqui a chave e a description, que e
  #    texto estatico escrito na configuracao.
  # 2. O FILTRO tambem nao pode testar esse ID. Comparar um valor desconhecido
  #    com null da um resultado desconhecido, e isso torna o mapa INTEIRO
  #    indeterminado em tempo de plan.
  #
  # Por isso o filtro olha para cidr_blocks, que e estatico: a validation da
  # variavel ja garante que a regra tem exatamente um dos dois campos, entao
  # "sem cidr_blocks" equivale a "tem SG de origem".
  sg_rules = {
    for regra in var.ingress_rules :
    regra.description => regra
    if regra.cidr_blocks == null
  }
}

resource "aws_security_group" "este" {
  name        = local.sg_name
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = local.sg_name })

  # A AWS nao renomeia SG in-place; sem isto, alterar o nome quebraria o apply
  # por conflito com os recursos ja associados.
  lifecycle {
    create_before_destroy = true
  }
}

# Regras em recursos separados em vez de blocos ingress inline: alterar uma
# regra passa a ser um diff de uma linha, e nao a recriacao do SG inteiro com
# tudo que depende dele.
resource "aws_vpc_security_group_ingress_rule" "por_cidr" {
  for_each = local.cidr_rules

  security_group_id = aws_security_group.este.id
  description       = each.value.description
  ip_protocol       = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_ipv4         = each.value.cidr
}

resource "aws_vpc_security_group_ingress_rule" "por_sg" {
  for_each = local.sg_rules

  security_group_id            = aws_security_group.este.id
  description                  = each.value.description
  ip_protocol                  = each.value.protocol
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  referenced_security_group_id = each.value.source_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count = var.enable_default_egress ? 1 : 0

  security_group_id = aws_security_group.este.id
  description       = "Permite todo o trafego de saida"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
