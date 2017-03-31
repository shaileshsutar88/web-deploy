packer validate -var-file=credentials.json $1 && packer build -var-file=credentials.json $1
