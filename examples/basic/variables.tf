variable "project_name" {
  type        = string
  description = "Name prefix for all resources."
  default     = "consul"
}

variable "consul_enterprise_license" {
  type        = string
  description = "Consul Enterprise license string."
  sensitive   = true
}
