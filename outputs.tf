output "bastion_instance_id" { value = aws_instance.bastion.id }
output "bastion_private_ip" { value = aws_instance.bastion.private_ip }
output "bastion_sg_id" { value = aws_security_group.bastion.id }
output "ssm_document_name" { value = aws_ssm_document.preferences.name }
output "log_group_name" { value = try(aws_cloudwatch_log_group.ssm[0].name, null) }
output "s3_log_bucket" { value = try(aws_s3_bucket.ssm_logs[0].bucket, null) }