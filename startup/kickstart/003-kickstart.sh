#!/bin/bash

AWS_SDK_VERSION=1.66.0

gem list aws-sdk | grep -o "aws-sdk ($AWS_SDK_VERSION)"
if [ $? -ne 0 ]; then
  sudo apt-get -q -y install libxslt-dev libxml2-dev
  sudo gem install aws-sdk --version $AWS_SDK_VERSION --no-ri --no-rdoc
fi

sudo mkdir -p /var/chef/{backup,tmp,cache}
