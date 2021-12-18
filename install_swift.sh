#!/bin/bash

if [[ ! -d /swift ]]
then
    mkdir /swift
fi

cd /swift
curl https://download.swift.org/swift-5.5.2-release/ubuntu1804/swift-5.5.2-RELEASE/swift-5.5.2-RELEASE-ubuntu18.04.tar.gz \
  --output toolchain-zipped

tar -xvzf toolchain-zipped -C /swift
rm toolchain-zipped 
echo pwd
mv swift-5.5.2-RELEASE-ubuntu18.04 toolchain

if [[ ! -d /projects ]]
then
    mkdir /projects
fi
cd /projects

if [[ ! -d Hello ]]
then
    mkdir Hello
fi
cd Hello

export PATH="/swift/toolchain/usr/bin:$PATH"

if [[ ! -e Package.swift ]]
then
    swift package init
fi
swift build
