from setuptools import setup, find_packages
# no sense in pip installing this because it doesn't define any symbols the Swift code needs to know beforehand
setup(name="swift_jupyter", version="5", packages=find_packages())
