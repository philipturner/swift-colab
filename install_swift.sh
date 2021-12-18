# $1 is Swift version (e.g. 5.5.2)

# Download Swift

if [[ ! -d /swift ]]
then
  mkdir /swift
fi

cd /swift

if [[ ! -d /swift/toolchain ]]
then  
  ver="5.5.2"
  tar_file="swift-${ver}-RELEASE-ubuntu18.04"
  url="https://download.swift.org/swift-${ver}-release/ubuntu1804/swift-${ver}-RELEASE/${tar_file}.tar.gz"
  
  curl "https://download.swift.org/swift-${ver}-release/ubuntu1804/swift-${ver}-RELEASE/${tar_file}.tar.gz" | tar -xz
  mv "${tar_file}" toolchain
  
#   curl https://download.swift.org/swift-5.5.2-release/ubuntu1804/swift-5.5.2-RELEASE/swift-5.5.2-RELEASE-ubuntu18.04.tar.gz \
#     | tar -xz
#   mv swift-5.5.2-RELEASE-ubuntu18.04 toolchain
fi

# Execute setup script

if [[ -d /swift/swift-colab ]]
then
  rm -r /swift/swift-colab
fi

git clone --single-branch -b main https://github.com/philipturner/swift-colab

export PATH="/swift/toolchain/usr/bin:$PATH"
swift swift-colab/install_swift.swift
