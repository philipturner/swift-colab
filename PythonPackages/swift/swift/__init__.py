import os 
def run(swift_string): 
  print("hello world pre")
  print(os.popen(f'bash /opt/swift/run_swift.sh "{swift_string}"').read())
