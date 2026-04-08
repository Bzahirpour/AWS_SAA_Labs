terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 6.0"
    }
  }
}
# This grabs the latest ami to be referenced in the resource block. This is good for test/dev but not recommended for prod. in prod we can reference an ami in variables.tf file and hardcode the ami id there. 
# This way we have more control over the ami we are using and we can test the new ami before updating the reference in variables.tf file.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "MyFirstEC2Instance" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = "A4l-Key"
  vpc_security_group_ids = ["sg-058214e963280c39d"]
  subnet_id = "subnet-0b54de95f9e228b1c"
  associate_public_ip_address = true

tags = {
    Name = "MyFirstEC2Instance"
  }
}