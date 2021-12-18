# Download Swift

if [[ ! -d /swift ]]
then
    mkdir /swift
fi

cd /swift

if [[ ! -d /swift/toolchain ]]
then
    curl https://download.swift.org/swift-5.5.2-release/ubuntu1804/swift-5.5.2-RELEASE/swift-5.5.2-RELEASE-ubuntu18.04.tar.gz \
        --output toolchain-tar
    
    tar -xvzf toolchain-tar -C /swift
    rm toolchain-tar
    mv swift-5.5.2-RELEASE-ubuntu18.04 toolchain
fi

# Execute setup script

if [[ -d /swift/swift-colab ]]
then
    rm -r /swift/swift-colab
fi

git clone --single-branch -b main https://github.com/philipturner/swift-colab

export PATH="/swift/toolchain/usr/bin:$PATH"
swift swift-colab/install_swift.swift

# cd /swift
# curl https://raw.githubusercontent.com/philipturner/swift-colab/main/install_swift.swift --output install_swift.swift

# export PATH="/swift/toolchain/usr/bin:$PATH"
# swift install_swift.swift
