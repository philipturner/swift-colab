# Download Swift

if [[ ! -d /opt/swift ]]
then
  mkdir /opt/swift
fi

cd /opt/swift

if [[ ! -d toolchain ]]
then  
  # $1 is the Swift version (e.g. 5.5.2)
  tar_file="swift-$1-RELEASE-ubuntu18.04"
  
  curl "https://download.swift.org/swift-$1-release/ubuntu1804/swift-$1-RELEASE/${tar_file}.tar.gz" | tar -xz
  mv "${tar_file}" toolchain
fi

# Execute setup script

if [[ -d swift-colab ]]
then
  rm -r swift-colab
fi

git clone --single-branch -b save-1 https://github.com/philipturner/swift-colab

export PATH="/opt/swift/toolchain/usr/bin:$PATH"
swift swift-colab/install_swift.swift
