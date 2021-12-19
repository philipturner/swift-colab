import subprocess

def run(swift_string):
  print("starting task 22")
  subprocess.run(["bash", "/swift/run_swift.sh", swift_string], capture_output=True, check=True, text=True)
  print("finishing task 22")
