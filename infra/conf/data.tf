data "aws_iam_role" "lab" {
  count = local.is_lab_env ? 1 : 0
  name  = "LabRole"
}
