if [[ $PATH != "/opt/swift/toolchain/usr/bin"* ]]
then
  export PATH="/opt/swift/toolchain/usr/bin:$PATH"
fi

swift /opt/swift/run_swift.swift "$1"
