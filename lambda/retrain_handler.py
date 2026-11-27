"""
AWS Lambda Handler for AECIP Autonomous Retraining.
Triggered on a recurring schedule by Amazon EventBridge or upon drift alerts.
Launches an autonomous ECS Fargate task to evaluate statistical drift,
execute AutoML re-tuning, and persist updated model artifacts to Amazon S3.
"""
import os
import json
import logging
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    EventBridge handler to launch the ECS Fargate model retraining workflow.
    """
    logger.info("Received retraining trigger event: %s", json.dumps(event))

    cluster_name = os.getenv("ECS_CLUSTER_NAME")
    task_def_arn = os.getenv("TASK_DEFINITION_ARN")
    subnets_str = os.getenv("SUBNET_IDS", "")
    security_group = os.getenv("SECURITY_GROUP_ID")
    region = os.getenv("AWS_REGION_NAME", "us-east-1")
    s3_bucket = os.getenv("AECIP_S3_BUCKET", "")

    subnets = [s.strip() for s in subnets_str.split(",") if s.strip()]

    # Validate configuration
    if not cluster_name or not task_def_arn or not subnets or not security_group:
        error_msg = (
            f"Missing required environment configurations: "
            f"cluster={cluster_name}, task_def={task_def_arn}, subnets={len(subnets)}, sg={security_group}"
        )
        logger.error(error_msg)
        return {
            "statusCode": 500,
            "body": json.dumps({"status": "ERROR", "message": error_msg})
        }

    ecs_client = boto3.client("ecs", region_name=region)
    cloudwatch_client = boto3.client("cloudwatch", region_name=region)

    try:
        logger.info(f"Dispatched ECS RunTask on cluster '{cluster_name}' using task definition '{task_def_arn}'...")

        response = ecs_client.run_task(
            cluster=cluster_name,
            taskDefinition=task_def_arn,
            launchType="FARGATE",
            count=1,
            networkConfiguration={
                "awsvpcConfiguration": {
                    "subnets": subnets,
                    "securityGroups": [security_group],
                    "assignPublicIp": "DISABLED"
                }
            },
            overrides={
                "containerOverrides": [
                    {
                        "name": "aecip-retrainer",
                        "environment": [
                            {"name": "RETRAINING_TRIGGERED_BY", "value": "AmazonEventBridge"},
                            {"name": "AECIP_S3_BUCKET", "value": s3_bucket}
                        ]
                    }
                ]
            }
        )

        tasks = response.get("tasks", [])
        failures = response.get("failures", [])

        if failures:
            logger.error("ECS RunTask reported failures: %s", json.dumps(failures))
            return {
                "statusCode": 502,
                "body": json.dumps({"status": "FAILED", "failures": failures})
            }

        task_arn = tasks[0]["taskArn"] if tasks else "UNKNOWN"
        logger.info(f"Successfully launched AECIP retraining task: {task_arn}")

        # Emit CloudWatch custom metric for RetrainingInvocations
        try:
            cloudwatch_client.put_metric_data(
                Namespace="AECIP/Retraining",
                MetricData=[
                    {
                        "MetricName": "RetrainingJobsTriggered",
                        "Value": 1.0,
                        "Unit": "Count"
                    }
                ]
            )
        except Exception as cw_err:
            logger.warning(f"Failed to emit CloudWatch metric: {cw_err}")

        return {
            "statusCode": 200,
            "body": json.dumps({
                "status": "SUCCESS",
                "message": "AECIP retraining task launched successfully on ECS Fargate.",
                "taskArn": task_arn
            })
        }

    except ClientError as e:
        logger.error(f"AWS ClientError during RunTask execution: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"status": "ERROR", "error": str(e)})
        }
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"status": "ERROR", "error": str(e)})
        }
