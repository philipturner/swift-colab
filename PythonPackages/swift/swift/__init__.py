import subprocess as sp
def run(swift_string):
  print(sp.run(["bash", "/opt/swift/run_swift.sh", swift_string], stdout=sp.PIPE, stderr=sp.STDOUT, text=True).stdout)
