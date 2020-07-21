provider "aws" {
	region = "ap-south-1"
        profile = "Divyansh"
}
//---------------------------------------------------------------

// VPC creation
resource "aws_vpc" "terra_vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "terra_vpc"
  }
}
//----------------------------------------------------------------

// Subnet creation
resource "aws_subnet" "terra_subnet" {
	depends_on = [
	   aws_vpc.terra_vpc,
 	 ]
  vpc_id     = aws_vpc.terra_vpc.id
  cidr_block = "192.168.5.0/24"
  availability_zone = "ap-south-1a" 
  //availability_zone_id = "aps1-az1"
  map_public_ip_on_launch = true
  tags = {
    Name = "terra_subnet"
  }
}

//-----------------------------------------------------------------

//Creation of security grp  ingress (inbound) or egress (outbound)
resource "aws_security_group" "task-2-sg" {

   depends_on = [
	   aws_vpc.terra_vpc,
           aws_subnet.terra_subnet,
 	 ]
  name        = "task-2-sg"
  description = "Allow TLS Inbound traffic"
  vpc_id      = aws_vpc.terra_vpc.id
    
    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NFS from EFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    description = "TLS from SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

  ingress {
    description = "TLS from HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 

tags = {
    Name = "task-2-sg"
  }
}


//----------------------------------------------------------------

resource "aws_internet_gateway" "task-2-igw" {
 vpc_id = aws_vpc.terra_vpc.id
 tags = {
        Name = "My task-2 VPC Internet Gateway"
     }
}


//-------------------------------------------------------------

resource "aws_route_table" "route-table-igw" {
   depends_on = [
	   aws_internet_gateway.task-2-igw,
 	 ]

  vpc_id = aws_vpc.terra_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task-2-igw.id
  }

  tags = {
    Name = "route-table"
  }
}

//-------------------------------------------------------------
resource "aws_route_table_association" "subnet-association" {
     depends_on = [
	   aws_route_table.route-table-igw,
 	 ]
  subnet_id      = aws_subnet.terra_subnet.id
  route_table_id = aws_route_table.route-table-igw.id
}


//----------------------------------------------------------------

// creation of EFS resource
resource "aws_efs_file_system" "efs_task" {
   
   depends_on = [
	   aws_route_table_association.subnet-association,
 	 ]
   creation_token = "efs_task"
   performance_mode = "generalPurpose"
   throughput_mode = "bursting"
   encrypted = "true"
 tags = {
     Name = "efs_task"
   }
 }

// EFS target mount 
resource "aws_efs_mount_target" "efs_mount" {
   
   depends_on = [
	   aws_efs_file_system.efs_task,
 	 ]
   file_system_id  = aws_efs_file_system.efs_task.id
   subnet_id = aws_subnet.terra_subnet.id
   security_groups = [aws_security_group.task-2-sg.id]
 }

//----------------------------------------------------------------



// EC2 launch
resource "aws_instance" "vmout" {
depends_on = [
    aws_efs_mount_target.efs_mount,
  ]
  ami           = "ami-0185e010d074994be"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.task-2-sg.id ]
  subnet_id = aws_subnet.terra_subnet.id
   key_name = "puttykey1234"
  
connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("D:/key1234.pem")
    host = aws_instance.vmout.public_ip
  }
 

  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y httpd git php amazon-efs-utils nfs-utils",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
      "sudo chmod ugo+rw /etc/fstab",
      "sudo echo '${aws_efs_file_system.efs_task.id}:/ /var/www/html efs tls,_netdev' >> /etc/fstab",
      "sudo mount -a -t efs,nfs4 defaults",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Divyansh-saxena/image-with-phpcode.git   /var/www/html/"
    ]
  }

  
tags = {
         Name = "EC2"
   } 
}
//----------------------------------------------------------------

 
//----------------------------------------------------------------

resource "aws_s3_bucket" "divyansh1222bucket"  {
  
   depends_on = [
           aws_security_group.task-2-sg,
 	 ]
  bucket = "divyanshbu22cketaws"
  acl = "public-read"
  force_destroy = true

 provisioner "local-exec" {
     command = "git clone  https://github.com/Divyansh-saxena/image-with-phpcode.git  D:/Terraform/TASK/upload "
   }
	
}

//----------------------------------------------------------------
resource "aws_s3_bucket_policy" "b67" {
depends_on = [
    aws_s3_bucket.divyansh1222bucket,
  ]
  bucket = "${aws_s3_bucket.divyansh1222bucket.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Sid": "IPAllow",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::divyanshbu22cketaws/*",
      "Condition": {
       "IpAddress": {"aws:SourceIp": "8.8.8.8/32"}
      }
    }
]
}
POLICY
}
//----------------------------------------------------------------

resource "aws_s3_bucket_object" "image_upload" {
    
depends_on = [
    aws_s3_bucket.divyansh1222bucket,
  ]
    bucket = aws_s3_bucket.divyansh1222bucket.bucket
    key = "wall.jpg"
    source = "D:/Terraform/TASK/upload/wall.jpg"
    acl = "public-read"	
    content_type = "image or jpeg"
}

//----------------------------------------------------------------
locals {
    s3_origin_id = aws_s3_bucket.divyansh1222bucket.bucket
    image_url = "${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.image_upload.key}"
}
//----------------------------------------------------------------

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
depends_on = [
    aws_s3_bucket.divyansh1222bucket,
  ]
  comment = "Sync CloudFront to S3"
}
//----------------------------------------------------------------

resource "aws_cloudfront_distribution" "s3_distribution" {
depends_on = [
    aws_s3_bucket.divyansh1222bucket,
  ]
    origin {
        domain_name = aws_s3_bucket.divyansh1222bucket.bucket_regional_domain_name
        origin_id = local.s3_origin_id

    s3_origin_config {
        origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
      } 
    }
	   
    enabled = true
    is_ipv6_enabled = true
    default_root_object = "index.php"


    custom_error_response {
        error_caching_min_ttl = 3000
        error_code = 404
        response_code = 200
        response_page_path = "/ibm-red-hat-leadspace.png"
    }


    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id


    forwarded_values {
        query_string = false
    cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all" 
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }
    
	restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }	
	
	viewer_certificate {
        cloudfront_default_certificate = true
      }


    tags = {
        Name = "Web-CF-Distribution"
      }

    connection {
        type = "ssh"
        user = "ec2-user"
        private_key = file("D:/key1234.pem") 
        host = aws_instance.vmout.public_ip
     }


    provisioner "remote-exec" {
        inline  = [
            "sudo chmod ugo+rw /var/www/html/",
            "echo \"<img src='http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.image_upload.key}'>\" >> /var/www/html/index.php",
          ]
      }

}

//----------------------------------------------------------------
output "cloudfront_ip_addr" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}
	
