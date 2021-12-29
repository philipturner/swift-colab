# Download Swift

if [[ ! -d /opt/swift ]]
then
  mkdir /opt/swift
fi

cd /opt/swift

if [[ -e version.txt ]]
then
  if [[ "$1" -ne `cat version.txt` ]]
  then
    echo "not equal"
  fi
fi

echo $1 > version.txt

if [[ ! -d toolchain ]]
then  
  # $1 is the Swift version (e.g. 5.5.2)
  echo "=== Downloading Swift ==="
  tar_file="swift-$1-RELEASE-ubuntu18.04"
  
  curl "https://download.swift.org/swift-$1-release/ubuntu1804/swift-$1-RELEASE/${tar_file}.tar.gz" | tar -xz
  mv "${tar_file}" toolchain
  
  apt install patchelf
  pip install wurlitzer
  
  mkdir packages
  cd packages
  git clone --single-branch -b master https://github.com/philipturner/PythonKit
  
  # Not installing Backtrace because I don't see it helping anything.
#   git clone --single-branch -b main https://github.com/philipturner/swift-backtrace
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
