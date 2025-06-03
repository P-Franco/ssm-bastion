#################################
# ---------- DATA SOURCES ----------
#################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#################################
# ---------- LOGGING ----------
#################################
resource "aws_kms_key" "ssm" {
  count               = (var.enable_cloudwatch_logs || var.enable_s3_logs) && var.create_kms_key ? 1 : 0
  description         = "KMS key for SSM session logging"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Root"
        Effect    = "Allow"
        Principal = { AWS = data.aws_caller_identity.current.account_id }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CWLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.name}.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })
  tags = var.tags
}

locals {
  kms_arn = length(aws_kms_key.ssm) > 0 ? aws_kms_key.ssm[0].arn : null
}

resource "aws_cloudwatch_log_group" "ssm" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/ssm/${var.name_prefix}-${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.kms_arn
  tags              = var.tags
}

resource "aws_s3_bucket" "ssm_logs" {
  count         = var.enable_s3_logs ? 1 : 0
  bucket        = "${var.name_prefix}-ssm-logs-${var.environment}"
  force_destroy = true
  tags          = var.tags
}

resource "aws_ssm_document" "preferences" {
  name          = "${var.name_prefix}-SSMPreferences-${var.environment}"
  document_type = "Session"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Session Manager preferences managed by Terraform"
    sessionType   = "Standard_Stream"
    inputs = {
      cloudWatchLogGroupName      = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.ssm[0].name : ""
      cloudWatchEncryptionEnabled = var.enable_cloudwatch_logs
      s3BucketName                = var.enable_s3_logs ? aws_s3_bucket.ssm_logs[0].bucket : ""
      s3EncryptionEnabled         = var.enable_s3_logs
      kmsKeyId                    = local.kms_arn != null ? local.kms_arn : ""
    }
  })
}

#################################
# ---------- VPC ENDPOINTS ----------
#################################
locals {
  endpoint_services = [
    "com.amazonaws.${data.aws_region.current.name}.ssm",
    "com.amazonaws.${data.aws_region.current.name}.ssmmessages",
    "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  ]
}

resource "aws_security_group" "endpoints" {
  count  = var.create_vpc_endpoints ? 1 : 0
  name   = "${var.name_prefix}-ssm-endpoints-sg-${var.environment}"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.allowed_cidrs
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  tags = var.tags
}

resource "aws_vpc_endpoint" "ssm" {
  count               = var.create_vpc_endpoints ? length(local.endpoint_services) : 0
  vpc_id              = var.vpc_id
  service_name        = local.endpoint_services[count.index]
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true
  tags                = merge(var.tags, { Name = "${var.name_prefix}-endpoint-${count.index}" })
}

# ingress from bastion → endpoint ENIs
resource "aws_security_group_rule" "ep_ingress_from_bastion" {
  count     = var.create_vpc_endpoints ? 1 : 0
  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  security_group_id        = aws_security_group.endpoints[0].id
  source_security_group_id = aws_security_group.bastion.id
}

#################################
# ---------- BASTION SG ----------
#################################
resource "aws_security_group" "bastion" {
  name   = "${var.name_prefix}-bastion-sg-${var.environment}"
  vpc_id = var.vpc_id
  tags   = var.tags
}

# egress to the internet when endpoints are **not** used
resource "aws_security_group_rule" "bastion_egress_internet" {
  count             = var.create_vpc_endpoints ? 0 : 1
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion.id
}

# egress to endpoint SG when endpoints are enabled
resource "aws_security_group_rule" "bastion_egress_endpoints" {
  count                    = var.create_vpc_endpoints ? 1 : 0
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion.id
  source_security_group_id = aws_security_group.endpoints[0].id # <— correct attr for remote SG
}

# optional SSH fallback
resource "aws_security_group_rule" "bastion_ingress_ssh" {
  for_each          = var.enable_ssh_fallback ? toset(var.allowed_ssh_cidrs) : toset({})
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [each.key]
  security_group_id = aws_security_group.bastion.id
  description       = "SSH fallback"
}

#################################
# ---------- IAM ----------
#################################
resource "aws_iam_role" "bastion" {
  name = "${var.name_prefix}-bastion-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "core" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "admin" {
  count      = var.attach_admin_policy ? 1 : 0
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name_prefix}-bastion-profile-${var.environment}"
  role = aws_iam_role.bastion.name
}

#################################
# ---------- EC2 ----------
#################################
resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  associate_public_ip_address = var.enable_public_ip

  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  user_data              = file("${path.module}/scripts/user_data.sh")

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-bastion" })
}
