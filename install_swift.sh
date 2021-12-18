# Download Swift

if [[ ! -d /swift ]]
then
  mkdir /swift
fi

cd /swift

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

git clone --single-branch -b main https://github.com/philipturner/swift-colab

export PATH="/swift/toolchain/usr/bin:$PATH"

base_dir="swift-colab/Sources/SwiftColab/install_swift"
echo "debug marker 1"
swift "${base_dir}/install_swift.swift"
echo "debug marker 2"
cd /env/python && ls
cd /swift
echo "debug marker 3"
mv -r /swift/swift-colab/PythonPackages/swift /env/python/swift

python3 "${base_dir}/install_swift.py"
