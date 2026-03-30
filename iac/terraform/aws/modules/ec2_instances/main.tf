resource "aws_instance" "this" {
  count = var.instance_count

  ami                         = var.instance_ami
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [var.sg_id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address  = true
  user_data                    = var.user_data != null ? base64encode(var.user_data) : null
  user_data_replace_on_change  = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.role}${count.index > 0 ? format("%02d", count.index) : ""}"
    Role = var.role
  })
}