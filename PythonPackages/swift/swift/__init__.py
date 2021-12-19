import subprocess

def run(swift_string):
  subprocess.run(["bash", "/swift/run_swift.sh", swift_string])
