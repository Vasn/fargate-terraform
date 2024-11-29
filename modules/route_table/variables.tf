variable "vpc_id" {}
variable "internet_gateway_id" {}

variable "nat_gateway_a_id" {}
variable "nat_gateway_b_id" {}

variable "public_subnet_1a_id" {}
variable "public_subnet_1b_id" {}
variable "web_subnet_1a_id" {}
variable "app_subnet_1a_id" {}
variable "app_subnet_1b_id" {}
variable "data_subnet_1a_id" {}
variable "data_subnet_1b_id" {}

variable "firewall_a_endpoint_id" {
  type = string
}

variable "firewall_b_endpoint_id" {
  type = string
}

variable "firewall_subnet_1a_id" {}
variable "firewall_subnet_1b_id" {}