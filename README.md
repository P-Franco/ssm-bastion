# ssm-bastion 🌐

[![CI](https://github.com/P-Franco/ssm-bastion/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/P-Franco/ssm-bastion/actions/workflows/ci.yml)

[![License: MIT](https://img.shields.io/github/license/P-Franco/ssm-bastion?cacheSeconds=3600)](LICENSE)


A reusable Terraform module that spins up an **EC2 bastion host reachable exclusively through AWS Systems Manager Session Manager**.  
It takes care of:

* Creating (or skipping) a KMS-encrypted CloudWatch/S3 log pipeline
* Optional VPC interface endpoints for fully private SSM traffic
* Minimal IAM role (`AmazonSSMManagedInstanceCore`) with an opt-in _admin_ flag
* Auto-generated Session-Manager preferences document
* Toggleable SSH fallback if you ever need to crack open port 22

> **Use-case** – drop a secure, audit-logged break-glass host into any VPC in two variables: `vpc_id` and `public_subnet_id`.

---

## 📐 Diagram (high-level)

```text
Developer ──► SSM Session
                  │
                  ▼
 ┌────────────────────────┐
 │     VPC (your app)     │
 │  ┌──────────┐          │
 │  │ Bastion  │──────────┤ private ENI
 │  └──────────┘          │
 │     ▲  ▲  ▲            │
 │     │  │  └── VPC endpoints (ssm, ec2messages, ssmmessages)
 │     │  └──── CloudWatch / S3 log sinks (optional)
 │     └─────── KMS key (optional)
 └────────────────────────┘
````

---

## 🚀 Quick start

```hcl
module "bastion" {
  source             = "git::https://github.com/P-Franco/ssm-bastion.git?ref=v0.1.3"

  name_prefix        = "demo"
  vpc_id             = module.vpc.id
  public_subnet_id   = module.vpc.public_subnets[0]
  private_subnet_ids = module.vpc.private_subnets

  ami_id             = "ami-04aa00acb1165b32a" # Amazon Linux 2023
}
```

Then:

```bash
terraform init
terraform apply
aws ssm start-session --target $(terraform output -raw bastion_instance_id)
```

Session transcripts land in CloudWatch Logs under `/ssm/demo`.

---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.40 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.99.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_instance_profile.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_kms_key.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.ssm_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_security_group.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.bastion_egress_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.bastion_egress_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.bastion_ingress_ssh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ep_ingress_from_bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_ssm_document.preferences](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_vpc_endpoint.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidrs"></a> [allowed\_cidrs](#input\_allowed\_cidrs) | n/a | `list(string)` | `[]` | no |
| <a name="input_allowed_ssh_cidrs"></a> [allowed\_ssh\_cidrs](#input\_allowed\_ssh\_cidrs) | n/a | `list(string)` | `[]` | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | Bastion specifics | `string` | n/a | yes |
| <a name="input_attach_admin_policy"></a> [attach\_admin\_policy](#input\_attach\_admin\_policy) | n/a | `bool` | `true` | no |
| <a name="input_create_kms_key"></a> [create\_kms\_key](#input\_create\_kms\_key) | n/a | `bool` | `true` | no |
| <a name="input_create_vpc_endpoints"></a> [create\_vpc\_endpoints](#input\_create\_vpc\_endpoints) | VPC Endpoints | `bool` | `true` | no |
| <a name="input_enable_cloudwatch_logs"></a> [enable\_cloudwatch\_logs](#input\_enable\_cloudwatch\_logs) | Logging / KMS | `bool` | `true` | no |
| <a name="input_enable_public_ip"></a> [enable\_public\_ip](#input\_enable\_public\_ip) | n/a | `bool` | `false` | no |
| <a name="input_enable_s3_logs"></a> [enable\_s3\_logs](#input\_enable\_s3\_logs) | n/a | `bool` | `true` | no |
| <a name="input_enable_ssh_fallback"></a> [enable\_ssh\_fallback](#input\_enable\_ssh\_fallback) | n/a | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | n/a | `string` | `"dev"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | n/a | `string` | `"t3.micro"` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | n/a | `number` | `90` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | n/a | `string` | `"bastion"` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | n/a | `list(string)` | n/a | yes |
| <a name="input_public_subnet_id"></a> [public\_subnet\_id](#input\_public\_subnet\_id) | n/a | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Network | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion_instance_id"></a> [bastion\_instance\_id](#output\_bastion\_instance\_id) | n/a |
| <a name="output_bastion_private_ip"></a> [bastion\_private\_ip](#output\_bastion\_private\_ip) | n/a |
| <a name="output_bastion_sg_id"></a> [bastion\_sg\_id](#output\_bastion\_sg\_id) | n/a |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | n/a |
| <a name="output_s3_log_bucket"></a> [s3\_log\_bucket](#output\_s3\_log\_bucket) | n/a |
| <a name="output_ssm_document_name"></a> [ssm\_document\_name](#output\_ssm\_document\_name) | n/a |
<!-- END_TF_DOCS -->

---

## 🛠️ Prerequisites

| Tool                      | Version tested | Purpose                |
| ------------------------- | -------------- | ---------------------- |
| Terraform                 | `>= 1.5`       | IaC engine             |
| AWS Provider              | `~> 5.40`      | cloud resources        |
| (Optional) tflint / tfsec | latest         | lint / security checks |

---

## 🔧 Optional knobs

| Variable                                    | Default     | When to flip                                                                |
| ------------------------------------------- | ----------- | --------------------------------------------------------------------------- |
| `enable_public_ip`                          | `false`     | Need SSH from the Internet (dev only).                                      |
| `enable_ssh_fallback`                       | `false`     | Open port 22 for `allowed_ssh_cidrs`.                                       |
| `attach_admin_policy`                       | `true`      | PoC speed; set to `false` and supply a custom policy once scopes are known. |
| `enable_cloudwatch_logs` / `enable_s3_logs` | both `true` | Choose where session logs land.                                             |

---

## 🤝 Contributing

1. Fork, branch from `main`.
2. `pre-commit install` → run the hooks.
3. Open PR — CI must be green.
4. Squash & merge.

---

## 📄 License

Apache-2.0 — see [LICENSE](LICENSE).

---
