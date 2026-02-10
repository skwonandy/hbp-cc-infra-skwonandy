variable "env" { type = string }
variable "project_name" { type = string; default = "hbp-cc" }
variable "domain_name" { type = string }
variable "tags" { type = map(string); default = {} }
