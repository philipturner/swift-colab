if [[ $PATH == "/swift/toolchain/usr/bin" ]]
then
  echo "Path contained swift"
  echo $PATH
else
  echo "Path did not contain swift"
  echo $PATH
fi

# export PATH="/swift/toolchain/usr/bin:$PATH"
