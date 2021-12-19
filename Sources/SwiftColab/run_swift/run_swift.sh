if [[ $PATH != "/opt/swift/toolchain/usr/bin"* ]]
then
  export PATH="/opt/swift/toolchain/usr/bin:$PATH"
fi

echo "hello world pre2"
swift /opt/swift/run_swift.swift "$1"
