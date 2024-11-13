provider "aws" {
    region = "${var.region}"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket  = "sample-bucket-durian"
  tags    = {
	Name          = "bucket_poc"
	Environment    = "testing"
  }
}