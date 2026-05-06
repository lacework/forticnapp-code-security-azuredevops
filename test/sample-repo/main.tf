resource "aws_s3_bucket" "insecure_bucket" {
bucket = "my-insecure-bucket-12345"

# Violation 1: Public read access enabled
acl = "public-read"

# Violation 2: No encryption at rest
# No server_side_encryption_configuration block

# Violation 3: No versioning
# versioning block missing

tags = {
    Name = "Insecure Bucket"
}
}

resource "aws_s3_bucket_public_access_block" "no_access_block" {
bucket = aws_s3_bucket.insecure_bucket.id

# Violation 4: All public access blocking disabled
block_public_acls       = false
block_public_policy     = false
ignore_public_acls      = false
restrict_public_buckets = false
}

resource "aws_instance" "web_server" {
ami           = "ami-12345678"
instance_type = "t2.micro"

# Violation 5: Hardcoded AWS access keys in user data
user_data = <<-EOF
    #!/bin/bash
    export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
    export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
EOF

# Violation 6: Security group allows all traffic from anywhere
vpc_security_group_ids = [aws_security_group.all_access.id]

# Violation 7: No encryption on EBS volumes
root_block_device {
    volume_type = "gp2"
    volume_size = 20
    # encrypted = false (default, but explicit would be better)
}
}

resource "aws_security_group" "all_access" {
name        = "all-access-sg"
description = "Allow all traffic"

# Violation 8: SSH open to entire internet
ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

# Violation 9: HTTP open to entire internet (common, but should be restricted)
ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

# Violation 10: All egress traffic allowed (should be restricted)
egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}
}

resource "aws_db_instance" "database" {
identifier     = "insecure-db"
engine         = "mysql"
instance_class = "db.t3.micro"

# Violation 11: No encryption at rest
# storage_encrypted = false (default)

# Violation 12: Publicly accessible
publicly_accessible = true

# Violation 13: No deletion protection
deletion_protection = false

# Violation 14: Weak password (hardcoded)
username = "admin"
password = "password123"

# Violation 15: No backup retention
backup_retention_period = 0
}

# Violation 16: IAM user with hardcoded credentials
resource "aws_iam_user" "hardcoded_user" {
name = "service-account"
path = "/"
}

resource "aws_iam_access_key" "user_key" {
user = aws_iam_user.hardcoded_user.name

# Violation 17: Access key created without rotation
# No pgp_key for encryption
}

# Violation 18: IAM policy with excessive permissions
resource "aws_iam_user_policy" "admin_policy" {
name = "admin-access"
user = aws_iam_user.hardcoded_user.name

policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
        Effect = "Allow"
        Action = "*"  # Full admin access
        Resource = "*"
    }
    ]
})
}
