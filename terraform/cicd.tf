# ---------------------------------------------------------
# GitHub Actions -> AWS via OIDC (no long-lived AWS keys)
# ---------------------------------------------------------

# Lets AWS trust short-lived tokens issued by GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# Only the deploy job of this repo, running in the "production"
# environment (after manual approval), can assume this role.
data "aws_iam_policy_document" "ci_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:environment:production"]
    }
  }
}

resource "aws_iam_role" "ci_deploy" {
  name               = "epicbook-ci-deploy"
  assume_role_policy = data.aws_iam_policy_document.ci_trust.json
}

# The role can only open/close rules on the EpicBook security group,
# so the runner can reach SSH for the duration of one deploy.
data "aws_iam_policy_document" "ci_sg" {
  statement {
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]
    resources = [aws_security_group.main.arn]
  }
}

resource "aws_iam_role_policy" "ci_sg" {
  name   = "epicbook-ci-sg-ssh"
  role   = aws_iam_role.ci_deploy.id
  policy = data.aws_iam_policy_document.ci_sg.json
}
