if [[ $PATH != "/swift/toolchain/usr/bin"* ]]
then
  export PATH="/swift/toolchain/usr/bin:$PATH"
fi

swift /swift/swift-colab/run_swift.swift "$1"
