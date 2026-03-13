
locals {
  cluster_endpoint = module.aurora_mysql.outputs.aurora_mysql_endpoint

  mysql_admin_user = module.aurora_mysql.outputs.aurora_mysql_master_username
  #mysql_admin_password     = local.enabled ? (length(var.mysql_admin_password) > 0 ? var.mysql_admin_password : one(data.aws_ssm_parameter.admin_password[*].value)) : ""
}

provider "mysql" {
  endpoint = local.cluster_endpoint
  username = local.mysql_admin_user
  password = local.mysql_admin_password

  # Useful for debugging provider
  # https://github.com/petoju/terraform-provider-mysql/blob/master/mysql/provider.go
  connect_retry_timeout_sec = 60
}
