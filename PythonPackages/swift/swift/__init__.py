import os

def run(swift_string):
  print("starting task 33")
  output = os.popen("bash /swift/run_swift.sh \"hello world\"")
  print(output.read())
  print("finishing task 33")
