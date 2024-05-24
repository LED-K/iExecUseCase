Pre-requisites : 
- Aws client installed and configured (credentials)
- Terrafor client installed
- Local SSH-keypair

Before launch : 
- Add your SSH pub key path.
- Double check your default aws region.
- Add an infura project key in the docker-compose section, in ethexporter environement.
- Add your wallet address in the addresses.txt section.

Usage : 
1 - terraform init
2 - terraform validate
3 - terrafor apply

This terrform script will automaticaly create an EC2 instance on AWS cloud, install necessary packages and run containers through docker-compose.
It will deploy : 
A grafana dahsboard on port 3000
Promtheus server on port 9090
Trefik reverse proxy accessible on port 8080
Ethexporter that will export all metrics of the wallets specified in addresses.text file.

Ec2 instance would be a linux Ubuntu 20.04.
It is still necessary to add route rules and affect elastic public ip manually in order to have public access.