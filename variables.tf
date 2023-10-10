variable "env" {
  description = "Name of the environment to deploy"
  type        = string
}

variable "prefix" {
  description = "Transformation Engine prefix"
  type        = string
}

variable "tre_permission_boundary_arn" {
  description = "ARN of the TRE permission boundary policy"
  type        = string
}
