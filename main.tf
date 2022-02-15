provider aws {
  region = "ap-south-1"
}



##################### creating a layer for flask module##################

resource "aws_lambda_layer_version" "lambda_layer" {
  filename   = "flask_layer.zip"
  layer_name = "flasklambda"

  compatible_runtimes = ["python3.6"]
}

################ creating a lambda role ####################

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}



########### creating a lambda function


resource "aws_lambda_function" "test_lambda" {
  filename      = "lambda_function_payload.zip"
  function_name = "my_flask"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "app.pretend"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256("lambda_function_payload.zip")

  runtime = "python3.6"
  layers = [aws_lambda_layer_version.lambda_layer.arn]
  depends_on = [aws_lambda_layer_version.lambda_layer]
}

################## integrating with api######################
####################################### creating a api to integrate with above lambda function #####################

resource "aws_api_gateway_rest_api" "example" {
  name = "example"
  endpoint_configuration {
    types = ["REGIONAL"]  ##############EDGE, REGIONAL or PRIVATE###########
  }
  depends_on = [aws_lambda_function.test_lambda]
}


################################# creating a resource in api ############################
resource "aws_api_gateway_resource" "MyDemoResource" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "mydemoresource"
}


############################## creating a method in api under above resource  #########################

resource "aws_api_gateway_method" "MyDemoMethod" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.MyDemoResource.id
  http_method   = "GET"     
  authorization = "NONE"
}


###################### api is integrating with lambda function ####################################

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.example.id  
  resource_id             = aws_api_gateway_resource.MyDemoResource.id  
  http_method             = aws_api_gateway_method.MyDemoMethod.http_method 
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "${aws_lambda_function.test_lambda.invoke_arn}"
}



############################# integration response####################
resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  resource_id = aws_api_gateway_resource.MyDemoResource.id
  http_method = aws_api_gateway_method.MyDemoMethod.http_method
  status_code = "200"
}



####################### response#################


resource "aws_api_gateway_method_response" "example222" {
    http_method         = aws_api_gateway_method.MyDemoMethod.http_method
    resource_id         = aws_api_gateway_resource.MyDemoResource.id
    rest_api_id         = aws_api_gateway_rest_api.example.id
    response_models     = {
        "application/json" = "Empty"
    }
#    response_parameters = {}
    status_code         = "200"
}


















############################################ creating a deployment for we need to to create a stage in api #############################
########################################## creating a stage for deploy a lambda or invoke lambda function #####################


