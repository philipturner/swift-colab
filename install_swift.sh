#!/bin/bash

if [[ ! -d /swift ]]
then
    mkdir /swift
fi

# Download Swift

cd /swift
curl https://download.swift.org/swift-5.5.2-release/ubuntu1804/swift-5.5.2-RELEASE/swift-5.5.2-RELEASE-ubuntu18.04.tar.gz \
  --output toolchain-zipped

tar -xvzf toolchain-zipped -C /swift
rm toolchain-zipped 
echo "Hello world 2"
pwd
mv swift-5.5.2-RELEASE-ubuntu18.04 toolchain

# Create directory for package

if [[ ! -d /projects/Hello ]]
then
    if [[ ! -d /projects ]]
    then
        mkdir /projects
    fi
    cd /projects
    mkdir /Hello
fi
cd /projects/Hello

# Test that Swift can compile

export PATH="/swift/toolchain/usr/bin:$PATH"

if [[ ! -e Package.swift ]]
then
    swift package init
fi
swift build
