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
  
  apt install patchelf
  
  
  mkdir packages
  cd packages
  # will activate this command once philipturner/PythonKit is stable
#   git clone --single-branch -b master https://github.com/philipturner/PythonKit
  git clone --single-branch -b "1.3.1" https://github.com/swift-server/swift-backtrace
  cd ../
fi

# Execute setup script

if [[ -d swift-colab ]]
then
  rm -r swift-colab
fi

git clone --single-branch -b main https://github.com/philipturner/swift-colab

export PATH="/opt/swift/toolchain/usr/bin:$PATH"
swift swift-colab/install_swift.swift
