import subprocess

def run(str):
  subprocess.run(["bash", "/swift/run_swift.sh", str])
