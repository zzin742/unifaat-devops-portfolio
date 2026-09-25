# Ambiente DEV — mesmos modulos do staging, variaveis diferentes.
# A senha NAO vai aqui: exporte TF_VAR_db_password antes do plan/apply.

environment = "dev"
vpc_cidr    = "10.0.0.0/16"

subnets = {
  "public-1a"  = { cidr = "10.0.1.0/24", az = "us-east-1a", type = "public" }
  "public-1b"  = { cidr = "10.0.2.0/24", az = "us-east-1b", type = "public" }
  "private-1a" = { cidr = "10.0.3.0/24", az = "us-east-1a", type = "private" }
  "private-1b" = { cidr = "10.0.4.0/24", az = "us-east-1b", type = "private" }
}

db_name = "technova_dev"

instance_type     = "t2.micro"
db_instance_class = "db.t3.micro"

# Restrinja ao seu IP: curl -s ifconfig.me
ssh_allowed_cidrs = ["0.0.0.0/0"]
