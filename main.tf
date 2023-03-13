#---------------------------
# Configure the AWS Provider
#---------------------------
provider "aws" {
  region = "us-east-1"
}
# ----------------------------------------------------
# Data Source para obtener el ID de la VPC por defecto
# ----------------------------------------------------
data "aws_vpc" "default" {
  #Devuelve la vpc por defecto
  default = true
}
# -----------------------------------------------
# Data source que obtiene el id del AZ eu-west-1a
# -----------------------------------------------
data "aws_subnet" "az_a" {
  availability_zone = "us-east-1a"
  vpc_id            = data.aws_vpc.default.id
}

# -----------------------------------------------
# Data source que obtiene el id del AZ eu-west-1a
# -----------------------------------------------
data "aws_subnet" "az_b" {
  availability_zone = "us-east-1b"
  vpc_id            = data.aws_vpc.default.id
}

#---------------------------
#Instancia EC2
#---------------------------
resource "aws_instance" "servidor_1" {
  ami                    = "ami-0557a15b87f6559cf"
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnet.az_a.id
  vpc_security_group_ids = [aws_security_group.mi_grupo_de_seguridad.id]
  tags = {
    "Name" = "mi_servidor_1"
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Hola Terraformers soy servidor 1!" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
}

resource "aws_instance" "servidor_2" {
  ami                    = "ami-0557a15b87f6559cf"
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnet.az_b.id
  vpc_security_group_ids = [aws_security_group.mi_grupo_de_seguridad.id]
  tags = {
    "Name" = "mi_servidor_2"
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Hola Terraformers soy servidor 2!" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
}
#---------------------------
#Security Group
#---------------------------
resource "aws_security_group" "mi_grupo_de_seguridad" {
  name = "primer-servidor-sg"
  ingress {
    #cidr_blocks = ["0.0.0.0/0"]
    #Acceso solo desde el Load Balancer
    security_groups = [aws_security_group.alb-sg.id]
    description     = "Acceso al puerto 8080 desde el exterior"
    from_port       = 8080
    to_port         = 8080
    protocol        = "TCP"
  }
}
#---------------------------
#Load Balancer
#---------------------------
resource "aws_lb" "alb" {
  load_balancer_type = "application"
  name               = "terraformers-alb"
  security_groups    = [aws_security_group.alb-sg.id]
  subnets            = [data.aws_subnet.az_a.id, data.aws_subnet.az_b.id]

}


#---------------------------
#Security Group Load Balancer
#---------------------------
resource "aws_security_group" "alb-sg" {
  name = "alb-sg"
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Acceso al puerto 80 desde el exterior"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Acceso al puerto 80 desde nuestros servidores"
    from_port   = 8080
    to_port     = 8080
    protocol    = "TCP"
  }

}

resource "aws_lb_target_group" "this" {
  name     = "terraformes-alb-target-group"
  port     = 80
  vpc_id   = data.aws_vpc.default.id
  protocol = "HTTP"

  health_check {
    enabled  = true
    matcher  = "200"
    path     = "/"
    port     = "8080"
    protocol = "HTTP"
  }
}

resource "aws_lb_target_group_attachment" "servidor_1" {
  target_group_arn = aws_lb_target_group.this.arn
  #Target ID = Instancia
  target_id = aws_instance.servidor_1.id
  port      = 8080
}

resource "aws_lb_target_group_attachment" "servidor_2" {
  target_group_arn = aws_lb_target_group.this.arn
  #Target ID = Instancia
  target_id = aws_instance.servidor_2.id
  port      = 8080
}

resource "aws_lb_listener" "this" {
  #Referenciamos nuestro Load Balancer
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.this.arn
    type             = "forward"
  }
}