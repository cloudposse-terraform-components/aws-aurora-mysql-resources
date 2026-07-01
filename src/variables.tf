variable "region" {
  type        = string
  description = "AWS Region"
}

variable "mysql_admin_password" {
  type        = string
  description = "MySQL password for the admin user. If not provided, the password will be pulled from SSM"
  default     = ""
  sensitive   = true
}

variable "aurora_mysql_component_name" {
  type        = string
  description = "Aurora MySQL component name to read the remote state from"
  default     = "aurora-mysql"
}

variable "read_passwords_from_ssm" {
  type        = bool
  default     = true
  description = "When `true`, fetch user passwords from SSM"
}

variable "ssm_path_prefix" {
  type        = string
  default     = "rds"
  description = "SSM path prefix"
}

variable "ssm_password_source" {
  type        = string
  default     = ""
  description = <<-EOT
    If var.read_passwords_from_ssm is true, DB user passwords will be retrieved from SSM using `var.ssm_password_source` and the database username. If this value is not set, a default path will be created using the SSM path prefix and ID of the associated Aurora Cluster.
    EOT
}

variable "mysql_cluster_enabled" {
  type        = string
  default     = true
  description = "Set to `false` to prevent the module from creating any resources"
}

variable "additional_databases" {
  type        = set(string)
  default     = []
  description = "Additional databases to be created with the cluster"
}

variable "additional_users" {
  # map key is service name
  type = map(object({
    db_user : string
    db_password : optional(string, "")
    auth_plugin : optional(string, "")
    role_memberships : optional(list(string), [])
    grants : optional(list(object({
      grant : list(string)
      db : string
    })), [])
  }))
  default     = {}
  description = <<-EOT
    Create additional database user for a service, specifying username, grants, and optional password.
    If no password is specified, one will be generated. Username and password will be stored in
    SSM parameter store under the service's key.
    Set `auth_plugin` (e.g. `AWSAuthenticationPlugin` for RDS IAM authentication) to create a user
    that authenticates via a MySQL authentication plugin instead of a password; no password is
    generated or stored for such users. `role_memberships` grants the listed MySQL roles (see
    `var.additional_roles`) to the user.
    EOT

  validation {
    condition = alltrue([
      for user in values(var.additional_users) :
      !(trimspace(user.auth_plugin) != "" && trimspace(user.db_password) != "")
    ])
    error_message = "additional_users[*] cannot set both `db_password` and `auth_plugin`; auth-plugin users do not use a password."
  }
}

variable "additional_roles" {
  type        = set(string)
  default     = []
  description = <<-EOT
    MySQL roles to create. Roles are GRANT targets that can be granted to users via
    `additional_users[*].role_memberships`. Requires MySQL 8.0+.
    EOT
}

variable "additional_grants" {
  # map key is user name
  type = map(list(object({
    grant : list(string)
    db : string
  })))
  default     = {}
  description = <<-EOT
    Create additional database user with specified grants.
    If `var.ssm_password_source` is set, passwords will be retrieved from SSM parameter store,
    otherwise, passwords will be generated and stored in SSM parameter store under the service's key.
    EOT
}
