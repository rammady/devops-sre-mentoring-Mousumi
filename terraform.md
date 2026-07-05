# Complete Beginner Playbook: Terraform AWS Demo

## What this creates

```text
S3 bucket for Terraform state
DynamoDB table for locking
VPC
Public subnet
Internet gateway
Route table
Security group
EC2 instance
```

---

# 1. Install tools

## Install AWS CLI on Mac

```bash
brew install awscli
```

Check:

```bash
aws --version
```

## Install Terraform on Mac

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

Check:

```bash
terraform version
```

---

# 2. Configure AWS CLI

Run:

```bash
aws configure
```

Enter:

```text
AWS Access Key ID: <your-access-key>
AWS Secret Access Key: <your-secret-key>
Default region name: ap-south-1
Default output format: json
```

Verify:

```bash
aws configure list
```

```bash
aws sts get-caller-identity
```

---

# 3. Create project folder

```bash
mkdir terraform-aws-demo
cd terraform-aws-demo
```

---

# 4. Create S3 bucket for Terraform state

Use your own unique bucket name.

```bash
aws s3 mb s3://my-terraform-state-demo-12345 --region ap-south-1
```

Enable versioning:

```bash
aws s3api put-bucket-versioning \
  --bucket my-terraform-state-demo-12345 \
  --versioning-configuration Status=Enabled
```

---

# 5. Create DynamoDB table for locking

```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
```

---

# 6. Create Terraform files

```bash
touch backend.tf provider.tf variables.tf main.tf outputs.tf terraform.tfvars
```

---

# 7. backend.tf

```bash
vi backend.tf
```

Paste:

```hcl
terraform {
  backend "s3" {
    bucket       = "my-terraform-state-demo-12345"
    key          = "dev/demo/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Note: New Terraform versions prefer `use_lockfile = true` instead of `dynamodb_table`.

---

# 8. provider.tf

```bash
vi provider.tf
```

Paste:

```hcl
provider "aws" {
  region = var.aws_region
}
```

---

# 9. variables.tf

```bash
vi variables.tf
```

Paste:

```hcl
variable "aws_region" {
  default = "ap-south-1"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance"
}

variable "instance_type" {
  default = "t3.micro"
}
```

---

# 10. terraform.tfvars

```bash
vi terraform.tfvars
```

Paste:

```hcl
aws_region    = "ap-south-1"
ami_id        = "ami-0f58b397bc5c1f2e8"
instance_type = "t3.micro"
```

---

# 11. Get your public IPv4

Run:

```bash
curl -4 ifconfig.me
```

Example:

```text
49.207.62.184
```

Use it with `/32`:

```text
49.207.62.184/32
```

---

# 12. main.tf

```bash
vi main.tf
```

Paste this code. Replace `49.207.62.184/32` with your own IP.

```hcl
resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "demo-vpc"
  }
}

resource "aws_subnet" "demo_subnet" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "demo-subnet"
  }
}

resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name = "demo-igw"
  }
}

resource "aws_route_table" "demo_rt" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }

  tags = {
    Name = "demo-route-table"
  }
}

resource "aws_route_table_association" "demo_assoc" {
  subnet_id      = aws_subnet.demo_subnet.id
  route_table_id = aws_route_table.demo_rt.id
}

resource "aws_security_group" "demo_sg" {
  name   = "demo-sg"
  vpc_id = aws_vpc.demo_vpc.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["49.207.62.184/32"]
  }

  ingress {
    description = "HTTP public access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "demo-sg"
  }
}

resource "aws_instance" "demo_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.demo_subnet.id
  vpc_security_group_ids = [aws_security_group.demo_sg.id]

  tags = {
    Name = "demo-ec2"
  }
}
```

---

# 13. outputs.tf

```bash
vi outputs.tf
```

Paste:

```hcl
output "ec2_public_ip" {
  value = aws_instance.demo_ec2.public_ip
}

output "vpc_id" {
  value = aws_vpc.demo_vpc.id
}
```

---

# 14. Run Terraform

Initialize:

```bash
terraform init
```

Format:

```bash
terraform fmt
```

Validate:

```bash
terraform validate
```

Plan:

```bash
terraform plan
```

Apply:

```bash
terraform apply
```

Type:

```text
yes
```

---

# 15. Verify in AWS

Check:

```text
AWS Console → EC2 → Instances
AWS Console → VPC → Your VPC
AWS Console → S3 → my-terraform-state-demo-12345
```

State file path:

```text
S3 bucket → dev/demo/terraform.tfstate
```

---

# 16. Common errors and fixes

## Error: region not set

Fix:

```bash
aws configure set default.region ap-south-1
```

## Error: invalid CIDR block

Wrong:

```hcl
cidr_blocks = ["49.207.62.184"]
```

Correct:

```hcl
cidr_blocks = ["49.207.62.184/32"]
```

## Error: t2.micro not eligible for Free Tier

Use:

```hcl
instance_type = "t3.micro"
```

## Warning: dynamodb_table deprecated

Use this in backend:

```hcl
use_lockfile = true
```

---

# 17. Destroy resources after demo

```bash
terraform destroy
```

Type:

```text
yes
```

---

# 18. Delete backend resources

Only after destroy:

```bash
aws s3 rm s3://my-terraform-state-demo-12345 --recursive
```

```bash
aws s3 rb s3://my-terraform-state-demo-12345
```

Optional, if DynamoDB table was created:

```bash
aws dynamodb delete-table \
  --table-name terraform-locks \
  --region ap-south-1
```

