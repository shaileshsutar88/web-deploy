#!/bin/bash

CHEF_VERSION=12.19.36

# Move the old rake out of the way for Chef
if [ -e /usr/local/bin/rake ]; then
  sudo mv /usr/local/bin/rake /usr/local/bin/rake.old
fi

gem list chef | grep -o "$CHEF_VERSION"
if [ $? -ne 0 ]; then
  sudo gem install chef --version $CHEF_VERSION --no-ri --no-rdoc
  sudo gem install deep_merge --no-ri --no-rdoc
fi
sudo mkdir -p /var/cache/chef-solo

# Move the old rake back after installing Chef
if [ -e /usr/local/bin/rake.old ]; then
  sudo mv /usr/local/bin/rake.old /usr/local/bin/rake
fi
