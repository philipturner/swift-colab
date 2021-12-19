import subprocess

def run(swift_string):
  print("starting task")
  subprocess.run(["bash", "/swift/run_swift.sh", swift_string])
  print("finishing task")
