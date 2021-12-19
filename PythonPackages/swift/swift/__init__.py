import os

def run(swift_string): 
  output = os.popen(f"bash /swift/run_swift.sh \"{swift_string}\"")
  print(output.read())
