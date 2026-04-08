terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "MyFirstEC2Instance" {
  ami           = "ami-0ea87431b78a82070"
  instance_type = "t2.micro"
  key_name      = "A4l-Key"
  vpc_security_group_ids = ["sg-058214e963280c39d"]
  subnet_id = "subnet-0b54de95f9e228b1c"
  associate_public_ip_address = true

tags = {
    Name = "MyFirstEC2Instance"
  }
}