import os

def run(swift_string): 
  command_string =  f"bash /swift/run_swift.sh \"${swift_string}\""
  print("command string is", command_string)
  output = os.popen(f"bash /swift/run_swift.sh \"${swift_string}\"")
  print(output.read())
