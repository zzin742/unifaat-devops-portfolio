# Modulo VPC — cria a rede a partir de um MAPA de subnets.
#
# Por que for_each e nao count: com count, as subnets ficam indexadas por
# posicao (aws_subnet.esta[0], [1], [2]...). Remover a subnet do meio da lista
# faz o Terraform renumerar as seguintes e planejar destruir e recriar subnets
# que nao mudaram. Com for_each a chave e o nome logico da subnet, e cada
# recurso tem endereco estavel: aws_subnet.esta["private-1a"].

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Separar por tipo uma unica vez deixa o resto do modulo legivel.
  public_subnets  = { for nome, cfg in var.subnets : nome => cfg if cfg.type == "public" }
  private_subnets = { for nome, cfg in var.subnets : nome => cfg if cfg.type == "private" }

  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

resource "aws_vpc" "esta" {
  cidr_block = var.vpc_cidr

  # Necessarios para o RDS ganhar endpoint DNS resolvivel dentro da VPC.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "esta" {
  vpc_id = aws_vpc.esta.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

resource "aws_subnet" "esta" {
  for_each = var.subnets

  vpc_id            = aws_vpc.esta.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  # So subnet publica recebe IP publico automatico.
  map_public_ip_on_launch = each.value.type == "public"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}"
    Tier = each.value.type
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.esta.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.esta.id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rt-public" })
}

# Route table privada sem rota 0.0.0.0/0: e a ausencia dessa rota que torna a
# subnet privada de fato. Nao ha NAT Gateway de proposito — o RDS nao precisa de
# saida para a internet e o NAT custaria credito do Learner Lab sem entregar
# nada a esta arquitetura.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.esta.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rt-private" })
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.esta[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = local.private_subnets

  subnet_id      = aws_subnet.esta[each.key].id
  route_table_id = aws_route_table.private.id
}
