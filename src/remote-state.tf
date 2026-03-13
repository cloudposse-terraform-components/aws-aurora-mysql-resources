module "aurora_mysql" {
  source  = "cloudposse/stack-config/yaml//modules/remote-state"
  version = "2.0.0"

  component = var.aurora_mysql_component_name

  context = module.this.context
}
