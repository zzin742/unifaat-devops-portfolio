# ============================================================================
# VPC
# ============================================================================
# enable_dns_hostnames é o que faz a EC2 receber um nome DNS público. Sem ele
# a instância sobe com IP mas sem hostname resolvível, e o SSH por nome falha.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# ============================================================================
# Subnets públicas — uma por AZ
# ============================================================================
# "Pública" não é um atributo da subnet: é consequência de ela estar associada
# a uma route table que aponta pro Internet Gateway. A distinção entre pública
# e privada aqui embaixo é inteiramente sobre roteamento.

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = data.aws_availability_zones.disponiveis.names[each.value.az_index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.key}"
    Tier = "public"
    AZ   = data.aws_availability_zones.disponiveis.names[each.value.az_index]
  })
}

# ============================================================================
# Subnets privadas — sem rota para a internet
# ============================================================================
# Ficam na route table PADRÃO da VPC, que só tem a rota local 10.0.0.0/16.
# Instância aqui conversa com o resto da VPC e não é alcançável de fora.
#
# Nota de custo: dar saída para internet a estas subnets exigiria um NAT
# Gateway (~US$ 32/mês). O enunciado não pede, e deixar sem NAT é o que mantém
# este trabalho dentro do Free Tier.

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = data.aws_availability_zones.disponiveis.names[each.value.az_index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.key}"
    Tier = "private"
    AZ   = data.aws_availability_zones.disponiveis.names[each.value.az_index]
  })
}

# ============================================================================
# Internet Gateway
# ============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# ============================================================================
# Route table pública
# ============================================================================
# Uma só, compartilhada pelas duas subnets públicas. Route table não é um
# recurso por AZ — o mesmo IGW atende a VPC inteira.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rt-public"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
