variable "vpc_id" {
  type        = string
  description = "VPC where endpoints will be created"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "One subnet per AZ for interface endpoint ENIs"
}

variable "route_table_ids" {
  type        = list(string)
  description = "Route tables to associate with the S3 gateway endpoint"
}

variable "instance_security_group_id" {
  type        = string
  description = "SG of EC2 instances that need SSM access"
}

variable "tags" {
  type    = map(string)
  default = {}
}
