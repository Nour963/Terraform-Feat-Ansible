provider "aws" {
    region = "eu-west-1"  
    
}

#VPC
resource "aws_vpc" "k8s_VPC" {
  cidr_block       = "10.240.0.0/24"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "kubernetes"
  }
}

#SUBNET
resource "aws_subnet" "k8s-SUB" {
  vpc_id     = "${aws_vpc.k8s_VPC.id}"
  cidr_block = "10.240.0.0/24"

  tags = {
    Name = "TFkubernetes"
  }
}

#INETERNET GATEWAY
resource "aws_internet_gateway" "k8s-GW" {
  vpc_id = "${aws_vpc.k8s_VPC.id}"

  tags = {
    Name = "TFkubernetes"
  }
}

#ROUTE TABLE
resource "aws_route_table" "k8s-RT" {
  vpc_id = "${aws_vpc.k8s_VPC.id}"
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.k8s-GW.id}"
  }

  
  tags = {
    Name = "TFkubernetes"
  }
}

#ROUTETABLE-SUBNET ASSOCIATION
resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.k8s-SUB.id}"
  route_table_id = "${aws_route_table.k8s-RT.id}"
}


#SECURITY GROUP
resource "aws_security_group" "k8s-SG" {
  vpc_id = "${aws_vpc.k8s_VPC.id}"
  name        = "kubernetes"
  description = "Kubernetes security group"

  ingress {
    from_port = 0
    to_port   = 0
    protocol    = -1
    cidr_blocks = ["10.240.0.0/24"]
  }
  ingress {
    from_port =  0
    to_port   = 0
    protocol    = -1
    cidr_blocks = ["10.200.0.0/16"]
  }

  
 ingress {
    from_port =   443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port = 6443
    to_port     = 6443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = -1 
    to_port     = -1
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }


  tags = {
    Name = "TFkubernetes"
  }
}



#SSH KEY
resource "aws_key_pair" "k8s-KEY" {
  key_name   = "k8shardkey"
  public_key = "${file("/home/nour/Documents/Terraform-files/AWS/k8s-hard/key/k8shardkey.pem.pub")}"
}


#WORKER NODES
resource "aws_instance" "k8s-WRKR" {

  ami           = "ami-03ef731cc103c9f09"
  instance_type = "t3.micro"
  key_name      = "${aws_key_pair.k8s-KEY.key_name}"
  subnet_id     = "${aws_subnet.k8s-SUB.id}"
  private_ip    = "10.240.0.21"
  security_groups = ["${aws_security_group.k8s-SG.id}"]
  associate_public_ip_address = true
  source_dest_check = false
  user_data     = "name=worker"
  

  tags = {
    Name  = "worker-1"
    
  }
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
    volume_type = "gp2"
    delete_on_termination = true
  }

   /*provisioner "local-exec" {
        command = "sleep 120; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --private-key /home/nour/Documents/Terraform-files/AWS/k8s-hard/key/k8shardkey.pem -i '${aws_instance.k8s-WRKR.public_ip},' master.yml"
    }*/
}

resource "null_resource" "etcd-masters" {


 provisioner "remote-exec" {
   connection {
    type         = "ssh"
    user         = "ubuntu"
    host         = "${aws_instance.k8s-WRKR.public_ip}"
    private_key  = "${file("/home/nour/Documents/Terraform-files/AWS/k8s-hard/key/k8shardkey.pem")}"
   
  }
     inline = ["sudo apt install python -y"]
}
  provisioner "local-exec" {
     command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${aws_instance.k8s-WRKR.public_ip},' master.yml"
  }
}
#--private-key /home/nour/Documents/Terraform-files/AWS/k8s-hard/key/k8shardkey.pem   