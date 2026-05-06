resource "aws_apigatewayv2_api" "visitor_count_api" {
  name          = "visitor_count_api_http"
  protocol_type = "HTTP"
  cors_configuration {
  allow_origins = ["https://clouddemarc.com"]
  allow_methods = ["POST"]
  allow_headers = ["content-type"]
  max_age       = 86400
}
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.visitor_count_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.db_update_fn.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_route" {
  api_id    = aws_apigatewayv2_api.visitor_count_api.id
  route_key = "POST /visitor-count"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.visitor_count_api.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 5
  }
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.db_update_fn.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_count_api.execution_arn}/*/*"
}

output "api_invoke_url" {
  value       = "${aws_apigatewayv2_api.visitor_count_api.api_endpoint}/visitor-count"
  description = "Full URL to POST to for incrementing the visitor counter"
}