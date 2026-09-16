data "aws_caller_identity" "current" {}

resource "dynatrace_aws_connection" "this" {
  name = var.account_name

  role_based_auth {
    consumers = ["SVC:com.dynatrace.da"]
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::314146291599:root"]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [dynatrace_aws_connection.this.id]
    }
  }
}

resource "aws_iam_role" "dynatrace" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  lifecycle {
    precondition {
      condition     = data.aws_caller_identity.current.account_id == var.account_id
      error_message = "The configured AWS credentials do not belong to account_id."
    }
  }
}

resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.dynatrace.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "dynatrace_aws_connection_role_arn" "this" {
  aws_connection_id = dynatrace_aws_connection.this.id
  role_arn          = aws_iam_role.dynatrace.arn

  depends_on = [aws_iam_role_policy_attachment.read_only]

  timeouts {
    create = "5m"
  }
}
