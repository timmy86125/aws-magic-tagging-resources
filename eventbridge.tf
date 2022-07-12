locals {
  lambda_assumed_event = "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${aws_iam_role.lambda_function_role.name}/${module.lambda.lambda_function_name}"
  event_pattern = [
    {
      service   = "EC2"
      source    = ["aws.ec2"]
      eventName = [{ "prefix" = "Create" }, "RunInstances", "AllocateAddress", "CopyImage", "CopySnapshot"]
    },
    {
      service   = "ELB"
      source    = ["aws.elasticloadbalancing"]
      eventName = ["CreateLoadBalancer", "CreateTargetGroup"]
    }
  ]
}

resource "aws_cloudwatch_event_rule" "event_rule" {
  count       = length(local.event_pattern)
  name        = "AWSAutoTaggingEventRule${local.event_pattern[count.index].service}"
  description = "Get the CloudTrail event from ${local.event_pattern[count.index].service}"
  event_pattern = jsonencode(
    {
      "source" : "${local.event_pattern[count.index].source}",
      "detail" : {
        "userIdentity" : {
          "arn" : [{
            "anything-but" : "${local.lambda_assumed_event}"
          }]
        },
        "eventName" : "${local.event_pattern[count.index].eventName}"
      }
    }
  )
}

resource "aws_cloudwatch_event_target" "event_rule" {
  count = length(local.event_pattern)
  rule  = aws_cloudwatch_event_rule.event_rule[count.index].name
  arn   = module.lambda.lambda_function_arn
}

resource "aws_lambda_permission" "event_rule" {
  count         = length(local.event_pattern)
  statement_id  = aws_cloudwatch_event_rule.event_rule[count.index].name
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event_rule[count.index].arn
}