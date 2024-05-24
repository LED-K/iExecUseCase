provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file(var.ssh_public_key_path)
}

resource "aws_instance" "docker" {
  ami           = "ami-09040d770ffe2224f"  # Ubuntu 20.04 LTS AMI
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name
  subnet_id     = aws_subnet.main.id
  security_groups = [aws_security_group.main.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y ca-certificates curl gnupg
              sudo install -m 0755 -d /etc/apt/keyrings
              sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
              sudo chmod a+r /etc/apt/keyrings/docker.asc
              sudo echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt-get update -y
              sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              sudo chmod +x /usr/local/bin/docker-compose
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ubuntu
              mkdir /home/ubuntu/app
              sudo chown ubuntu:ubuntu /home/ubuntu/app
              
              # Create addresses.txt
              cat << 'EOL' > /home/ubuntu/app/addresses.txt
              khaled:0x9963A47a748620aC723031B1159Af237fC1102af
              bittrex:0xFBb1b73C4f0BDa4f67dcA266ce6Ef42f520fBB98
              EOL

              # Create prometheus.yml
              cat << 'EOL' > /home/ubuntu/app/prometheus.yml
              global:
                scrape_interval: 15s

              scrape_configs:
                - job_name: 'ethexporter'
                  static_configs:
                    - targets: ['ethexporter:9308']
              EOL

              cat << 'EOL' > /home/ubuntu/app/docker-compose.yml
              version: '3.9'

              services:
                traefik:
                  image: traefik:v2.6
                  container_name: traefik
                  command:
                    - "--api.insecure=true"
                    - "--providers.docker=true"
                    - "--entrypoints.web.address=:80"
                    - "--log.level=DEBUG"
                    - "--accesslog"
                  ports:
                    - "80:80"
                    - "8080:8080"
                  volumes:
                    - /var/run/docker.sock:/var/run/docker.sock
                    - ./ipwhitelist.yml:/config/ipwhitelist.yml

                ethexporter:
                  image: hunterlong/ethexporter:latest
                  container_name: ethexporter
                  environment:
                    - GETH=https://sepolia.infura.io/v3/INFURAPTOJECTKEY
                    - PORT=9308
                  ports:
                    - "9308:9308"
                  volumes:
                    - ./addresses.txt:/app/addresses.txt
                    - ethexporter_data:/app/data

                prometheus:
                  image: prom/prometheus:latest
                  container_name: prometheus
                  volumes:
                    - ./prometheus.yml:/etc/prometheus/prometheus.yml
                    - prometheus_data:/prometheus
                  ports:
                    - "9090:9090"

                grafana:
                  image: grafana/grafana:latest
                  container_name: grafana
                  labels:
                    - "traefik.enable=true"
                    - "traefik.http.routers.grafana.rule=Host(`grafana`)"
                    - "traefik.http.routers.grafana.entrypoints=web"
                    - "traefik.http.routers.grafana.middlewares=test-ipwhitelist"
                    - "traefik.http.middlewares.test-ipwhitelist.ipwhitelist.sourcerange=127.0.0.1/32,192.168.1.14"
                  ports:
                    - "3000:3000"
                  environment:
                    - GF_SECURITY_ADMIN_PASSWORD=test123*
                  volumes:
                    - grafana_data:/var/lib/grafana

              volumes:
                ethexporter_data:
                prometheus_data:
                grafana_data:
              EOL
              cd /home/ubuntu/app
              sudo docker-compose up -d
              EOF

  tags = {
    Name = "docker-compose-instance"
  }
}

variable "aws_region" {
  description = "The AWS region to create resources in."
  default     = "us-east-2"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key."
  default     = "~/.ssh/....."
}
