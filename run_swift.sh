if [[ $PATH == "/swift/toolchain/usr/bin"* ]]
then
  echo "Path contained swift: $PATH"
  echo $PATH
else
  echo "Path did not contain swift 2"
  echo $PATH
  
  export PATH="/swift/toolchain/usr/bin:$PATH"
fi

echo "trying again"

if [[ $PATH == "/swift/toolchain/usr/bin"* ]]
then
  echo "Path contained swift: $PATH"
  echo $PATH
else
  echo "Path did not contain swift 2"
  echo $PATH
  
  export PATH="/swift/toolchain/usr/bin:$PATH"
fi
