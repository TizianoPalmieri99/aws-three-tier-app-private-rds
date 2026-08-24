# Inputs of the network module. Nothing here has a default except the NAT
# choice: the environment decides what a network looks like.

variable "name_prefix" {
  description = "Prefix used to name every resource, so they are easy to find and delete together."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability Zones used for the subnets. The list order maps to the subnet CIDR lists."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets, one per Availability Zone."
  type        = list(string)
}

variable "app_subnet_cidrs" {
  description = "CIDR blocks of the private application subnets, one per Availability Zone."
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "CIDR blocks of the private database subnets, one per Availability Zone."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "True for one shared NAT Gateway, false for one per Availability Zone. False costs more and removes a single point of failure."
  type        = bool
  default     = true
}
