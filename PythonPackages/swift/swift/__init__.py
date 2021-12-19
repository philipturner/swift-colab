import subprocess as sp
def run(swift_string):
    p = sp.run(["bash", "/opt/swift/run_swift.sh", swift_string], stdout=sp.PIPE, stderr=sp.PIPE, text=True); print(p.stdout + p.stderr)
