data "aws_ssm_parameter" "account_ids" {
  name            = var.account_ids_ssm_path
  with_decryption = false

  lifecycle {
    postcondition {
      condition     = contains(["String", "StringList"], self.type)
      error_message = "The account inventory must use an SSM String or StringList, not SecureString."
    }
  }
}

data "aws_ssm_parameter" "dev_accounts" {
  name            = "/arecps/dynatrace/dev_accounts"
  with_decryption = false

  lifecycle {
    postcondition {
      condition     = contains(["String", "StringList"], self.type)
      error_message = "The dev account inventory must use an SSM String or StringList."
    }
  }
}

data "aws_ssm_parameter" "tst_accounts" {
  name            = "/arecps/dynatrace/tst_accounts"
  with_decryption = false

  lifecycle {
    postcondition {
      condition     = contains(["String", "StringList"], self.type)
      error_message = "The tst account inventory must use an SSM String or StringList."
    }
  }
}
