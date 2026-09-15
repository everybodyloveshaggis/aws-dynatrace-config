data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "dynatrace" {
  url            = "https://token.dynatrace.com"
  client_id_list = ["${trimsuffix(var.dynatrace_environment_url, "/")}/app-id/dynatrace.aws.connector"]
}

resource "dynatrace_aws_connection" "this" {
  name = var.account_name

  web_identity {
    consumers = ["APP:dynatrace.aws.connector"]
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.dynatrace.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.dynatrace.com:sub"
      values   = ["dt:connection-id/${dynatrace_aws_connection.this.id}"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.dynatrace.com:aud"
      values   = ["${trimsuffix(var.dynatrace_environment_url, "/")}/app-id/dynatrace.aws.connector"]
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

  timeouts {
    create = "5m"
  }
}