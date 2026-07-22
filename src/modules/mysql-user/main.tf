locals {
  enabled = module.this.enabled

  # Password machinery applies only to password-authenticated users. Users with an
  # `auth_plugin` set (e.g. RDS IAM auth) have no password to generate or store.
  use_password = local.enabled && var.auth_plugin == ""

  db_user     = length(var.db_user) > 0 ? var.db_user : var.service_name
  db_password = length(var.db_password) > 0 ? var.db_password : join("", random_password.db_password[*].result)

  save_password_in_ssm = local.use_password && var.save_password_in_ssm

  db_password_key = format("%s/%s/passwords/%s", var.ssm_path_prefix, var.service_name, local.db_user)
  db_password_ssm = local.save_password_in_ssm ? {
    name        = local.db_password_key
    value       = local.db_password
    description = "MySQL Password for DB user ${local.db_user}"
    type        = "SecureString"
    overwrite   = true
  } : null

  parameter_write = local.save_password_in_ssm ? [local.db_password_ssm] : []

  # You cannot grant "ALL" to an RDS user because "ALL" includes privileges that Master does not have (because this is a managed database).
  # Instead, use "ALL PRIVILEGES"
  # See the full list of available options at https://docs.amazonaws.cn/en_us/AmazonRDS/latest/AuroraUserGuide/AuroraMySQL.Security.html
  all_rds_app_grants = [
    "ALL PRIVILEGES"
  ]
  all_rds_other_grants = [
    "CREATE USER",
    "GRANT OPTION",
    "PROCESS",
    "RELOAD",
    "REPLICATION CLIENT",
    "REPLICATION SLAVE",
    "SHOW DATABASES",
  ]
  all_grants = distinct(concat(local.all_rds_app_grants, local.all_rds_other_grants))
}

resource "random_password" "db_password" {
  count   = local.use_password && length(var.db_password) == 0 ? 1 : 0
  length  = 33
  special = false

  keepers = {
    db_user = local.db_user
  }
}

resource "mysql_user" "default" {
  count = local.enabled ? 1 : 0
  user  = local.db_user
  host  = "%"
  # Password users set `plaintext_password`; auth-plugin users (e.g. RDS IAM) set `auth_plugin`
  # instead and have no password.
  plaintext_password = var.auth_plugin == "" ? local.db_password : null
  auth_plugin        = var.auth_plugin == "" ? null : var.auth_plugin
}

# Grant MySQL role memberships to the user (GRANT <role> TO <user>).
resource "mysql_grant" "role_membership" {
  count = local.enabled && length(var.role_memberships) > 0 ? 1 : 0
  user  = join("", mysql_user.default[*].user)
  host  = join("", mysql_user.default[*].host)
  roles = var.role_memberships

  depends_on = [mysql_user.default]
}

# Grant the user full access to this specific database
resource "mysql_grant" "default" {
  count    = local.enabled ? length(var.grants) : 0
  user     = join("", mysql_user.default[*].user)
  host     = join("", mysql_user.default[*].host)
  database = split(".", var.grants[count.index].db)[0]
  # We would like to use
  # table = try(split(".", var.grants[count.index].db)[1], "*")
  # but when we create the database, no tables exist, and we cannot
  # limit a grant to a non-existent table.
  table = "*"

  privileges = flatten([for grant in var.grants[count.index].grant : (
    grant == "ALL_APP" ? local.all_rds_app_grants : grant == "ALL" ? local.all_grants : [grant]
  )])

  depends_on = [mysql_user.default]
}

module "parameter_store_write" {
  source  = "cloudposse/ssm-parameter-store/aws"
  version = "0.13.0"

  # kms_arn will only be used for SecureString parameters
  kms_arn = var.kms_key_id # not necessarily ARN — alias works too

  parameter_write = local.parameter_write

  context = module.this.context
}
