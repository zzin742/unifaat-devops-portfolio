terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # State local nesta entrega: o TF da aula 05 ja cobriu backend remoto, e aqui
  # o foco e a biblioteca de modulos. Num ambiente real, cada environment teria
  # seu proprio backend "s3" com key distinta, para dev e staging nunca
  # compartilharem state.
}

provider "aws" {
  region = var.aws_region

  # default_tags aplica a todo recurso criado pelo provider, inclusive os que um
  # modulo esquecer de taguear.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Aluno       = "Jose Henrique Teixeira Luiz"
      RA          = "3225002"
      Disciplina  = "DevOps"
      ManagedBy   = "Terraform"
    }
  }
}
