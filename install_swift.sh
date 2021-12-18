# $1 is Swift version (e.g. 5.5.2)

# Download Swift

if [[ ! -d /swift ]]
then
  mkdir /swift
fi

cd /swift

if [[ ! -d /swift/toolchain ]]
then  
  args=("$@")
  echo "troubleshooting args"
  echo ${args[0]}
  echo ${args[1]}
  echo $#
  echo args[0]
  echo args[1]
  echo $args[0]
  echo $args[1]
#   echo "version: $] alt: $@[0]"
#   echo $@
#   echo $@[0]
#   echo $@[1]
  ver="5.5.2"
  tar_file="swift-$1-RELEASE-ubuntu18.04"
  
  curl "https://download.swift.org/swift-$1-release/ubuntu1804/swift-$1-RELEASE/${tar_file}.tar.gz" | tar -xz
  mv "${tar_file}" toolchain
fi

# Execute setup script

if [[ -d /swift/swift-colab ]]
then
  rm -r /swift/swift-colab
fi

git clone --single-branch -b main https://github.com/philipturner/swift-colab

export PATH="/swift/toolchain/usr/bin:$PATH"
swift swift-colab/install_swift.swift
