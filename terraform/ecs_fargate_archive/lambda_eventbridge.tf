# --- Package Lambda Source Code into Zip ---
data "archive_file" "lambda_retrain_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda_retrainer.zip"
}

# --- AWS Lambda Function for Autonomous Retraining Trigger ---
resource "aws_lambda_function" "retrainer" {
  filename         = data.archive_file.lambda_retrain_zip.output_path
  source_code_hash = data.archive_file.lambda_retrain_zip.output_base64sha256
  function_name    = "${var.project_name}-${var.environment}-scheduled-retrainer"
  role             = aws_iam_role.lambda_retrain_role.arn
  handler          = "retrain_handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 300 # 5 minutes
  memory_size      = 256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ECS_CLUSTER_NAME    = aws_ecs_cluster.main.name
      TASK_DEFINITION_ARN = aws_ecs_task_definition.retraining.arn
      SUBNET_IDS          = join(",", aws_subnet.private[*].id)
      SECURITY_GROUP_ID   = aws_security_group.ecs.id
      AECIP_S3_BUCKET     = aws_s3_bucket.artifacts.id
      AWS_REGION_NAME     = var.aws_region
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-retrainer"
    Description = "Orchestrates automated retraining jobs on Amazon ECS Fargate via EventBridge"
  }
}

# --- CloudWatch Log Group for Lambda Function ---
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.retrainer.function_name}"
  retention_in_days = 30
}

# --- Amazon EventBridge Scheduled Rule (Cron Trigger) ---
resource "aws_cloudwatch_event_rule" "retrain_schedule" {
  name                = "${var.project_name}-${var.environment}-retrain-schedule"
  description         = "Triggers AECIP automated model retraining and drift verification on a schedule"
  schedule_expression = var.retraining_cron_schedule
  state               = "ENABLED"

  tags = {
    Name = "${var.project_name}-${var.environment}-retrain-schedule"
  }
}

# --- EventBridge Target Pointing to Lambda Function ---
resource "aws_cloudwatch_event_target" "retrain_target" {
  rule      = aws_cloudwatch_event_rule.retrain_schedule.name
  target_id = "AecipLambdaRetrainerTarget"
  arn       = aws_lambda_function.retrainer.arn
}

# --- Lambda Permission for EventBridge Invocation ---
resource "aws_lambda_permission" "allow_eventbridge_to_invoke_retrainer" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.retrainer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.retrain_schedule.arn
}
