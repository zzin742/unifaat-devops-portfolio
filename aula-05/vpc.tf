# ============================================================================
# Rede
# ============================================================================
# Desenho: a EC2 fica exposta na subnet publica; o RDS fica isolado nas
# privadas, sem rota para a internet. A unica forma de alcancar o banco e a
# partir de dentro da VPC.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # o endpoint do RDS e um nome DNS, nao um IP

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.disponiveis.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public"
    Tier = "public"
  })
}

# for_each em vez de count: com count, remover a primeira subnet renumera as
# outras e o Terraform destroi e recria recursos que nao mudaram. A chave do
# map e estavel.
resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = data.aws_availability_zones.disponiveis.names[each.value.az_index]

  # Sem IP publico: e o que mantem o banco inalcancavel de fora.
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${each.key}"
    Tier = "private"
  })
}

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
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# As subnets privadas NAO recebem route table propria de proposito. Ficam na
# route table default da VPC, que so tem a rota local (10.0.0.0/16) - sem
# saida para a internet. Um NAT Gateway daria essa saida, mas custa por hora
# e continua cobrando entre as sessoes do Learner Lab. O RDS nao precisa dele.

# ============================================================================
# DB Subnet Group
# ============================================================================
# Diz ao RDS em quais subnets ele pode se colocar. Exige no minimo duas AZs,
# mesmo com multi_az = false.
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [for s in aws_subnet.private : s.id]

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}
