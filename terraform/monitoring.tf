# SNS topic for infrastructure alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
  tags = local.common_tags
}

# Email subscription — AWS sends a confirmation email on first apply
# You must click "Confirm subscription" in that email before alerts are delivered
resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudFront 4xx error rate > 5% for two consecutive 5-minute periods
resource "aws_cloudwatch_metric_alarm" "cf_4xx_high" {
  alarm_name          = "${var.project_name}-${var.environment}-cf-4xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "CloudFront 4xx error rate exceeded 5% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site_distribution.id
    Region         = "Global"
  }

  tags = local.common_tags
}

# CloudFront 5xx error rate > 1% for two consecutive 5-minute periods
resource "aws_cloudwatch_metric_alarm" "cf_5xx_high" {
  alarm_name          = "${var.project_name}-${var.environment}-cf-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "CloudFront 5xx error rate exceeded 1% for 10 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site_distribution.id
    Region         = "Global"
  }

  tags = local.common_tags
}
