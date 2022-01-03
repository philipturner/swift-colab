# Download Swift

if [[ ! -d /opt/swift ]]
then
  mkdir /opt/swift
fi

cd /opt/swift
should_reinstall="false"

if [[ -e "swiftpm-version.txt" ]]
then
  if [[ "$1" != `cat "swiftpm-version.txt"` ]]
  then
    rm -r toolchain
    should_reinstall="true"
  fi
fi

echo $1 > "swiftpm-version.txt"

if [[ ! -d toolchain ]]
then  
  echo "=== Downloading Swift ==="
  
  if [[ "$#" == "2" ]]
  then
    if [[ $2 == "development" ]]
    then
      # $1 is the snapshot date (e.g. 2021-12-23)
      tar_file="swift-DEVELOPMENT-SNAPSHOT-$1-a-ubuntu18.04"
      curl "https://download.swift.org/development/ubuntu1804/swift-DEVELOPMENT-SNAPSHOT-$1-a/${tar_file}.tar.gz" | tar -xz
    else
      # You chose something custom and must specify both the URL and tar file name
      tar_file = $2
      curl $1 | tar -xz
    fi
  else
    # $1 is the Swift version (e.g. 5.5.2)
    tar_file="swift-$1-RELEASE-ubuntu18.04"
    curl "https://download.swift.org/swift-$1-release/ubuntu1804/swift-$1-RELEASE/${tar_file}.tar.gz" | tar -xz
  fi
  
  mv "${tar_file}" toolchain
  
  apt install patchelf
  pip install wurlitzer
  
  if [[ $should_reinstall == "false" ]]
  then
    mkdir packages
    cd packages
    git clone --single-branch -b master https://github.com/philipturner/PythonKit
    cd ../
  fi
fi

# Execute setup script

if [[ -d swift-colab ]]
then
  rm -r swift-colab
fi

git clone --single-branch -b main https://github.com/philipturner/swift-colab

export PATH="/opt/swift/toolchain/usr/bin:$PATH"
swift swift-colab/install_swift.swift $should_reinstall
