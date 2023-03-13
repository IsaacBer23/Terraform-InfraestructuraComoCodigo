variable "puerto_servidor" {
  description = "Puerto para las instancias EC2"
  type        = number
}

variable "puerto_lb" {
  description = "Puerto para el LB"
  type        = number
}

variable "tipo_instancia" {
  description = "Tipo de las instancias EC2"
  type        = string
}