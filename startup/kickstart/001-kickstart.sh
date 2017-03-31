#!/bin/bash

RUBY_VERSION=2.4.0
RUBY_DL_URL=https://cache.ruby-lang.org/pub/ruby/2.4/ruby-2.4.0.tar.gz
RUBY_DL_SHA=152fd0bd15a90b4a18213448f485d4b53e9f7662e1508190aa5b702446b29e3d
FILENAME="$(basename "${RUBY_DL_URL}")"
CONFIGURE_OPTS="--disable-install-doc"

ruby -v | grep -o "ruby $RUBY_VERSION"
if [ $? -ne 0 ]; then
  export DEBIAN_FRONTEND=noninteractive

  sudo apt-get -q -y update
  sudo apt-get -q -y install zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev

  echo "Downloading ${RUBY_DL_URL}..."
  wget -q $RUBY_DL_URL

  if [ "$(sha256sum ${FILENAME} | cut -d ' ' -f1)" != "${RUBY_DL_SHA}" ]; then
    echo "Expected: ${RUBY_DL_SHA}"
    echo "Got:      $(sha256sum ${FILENAME} | cut -d ' ' -f1)"
    echo "W00ps. SHA256 doesn't match" 1>&2
    exit 1
  fi

  echo "Extracting ${FILENAME}..."
  tar zxf "${FILENAME}"
  cd "${FILENAME%.*.*}"

  ./configure $CONFIGURE_OPTS

  make
  sudo make install
  . ~/.bashrc
  echo "Succesfully installed $(ruby -v)"

  cd ..
  rm -rf "${FILENAME%.*.*}"
  rm -rf "${FILENAME}"

  echo "gem: --no-ri --no-rdoc" > ~/.gemrc
  sudo gem update --system
fi
