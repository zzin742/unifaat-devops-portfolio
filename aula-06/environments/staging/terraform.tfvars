# Ambiente STAGING — mesmos modulos do dev, variaveis diferentes.
# A senha NAO vai aqui: exporte TF_VAR_db_password antes do plan/apply.

environment = "staging"
vpc_cidr    = "10.1.0.0/16"

subnets = {
  "public-1a"  = { cidr = "10.1.1.0/24", az = "us-east-1a", type = "public" }
  "public-1b"  = { cidr = "10.1.2.0/24", az = "us-east-1b", type = "public" }
  "private-1a" = { cidr = "10.1.3.0/24", az = "us-east-1a", type = "private" }
  "private-1b" = { cidr = "10.1.4.0/24", az = "us-east-1b", type = "private" }
}

db_name = "technova_staging"

instance_type     = "t2.micro"
db_instance_class = "db.t3.micro"

ssh_allowed_cidrs = ["0.0.0.0/0"]
