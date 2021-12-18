if [[ $PATH != "/swift/toolchain/usr/bin"* ]]
then
  export PATH="/swift/toolchain/usr/bin:$PATH"
fi

swift /swift/run_swift.swift "$1"
