from setuptools import setup, find_packages

VERSION = '1.0.0' 
DESCRIPTION = 'Execute Swift code from Python'
LONG_DESCRIPTION = 'Allows running Swift code as Python strings in Google Colab'

# Setting up
setup(
    # the name must match the folder name 'swift'
    name="swift", 
    version="",
    author="Philip Turner",
    author_email="philipturner.AR@gmail.com",
    description=DESCRIPTION,
    long_description=LONG_DESCRIPTION,
    packages=find_packages(),
    install_requires=[], # add any additional packages that 
    # need to be installed along with your package. Eg: 'caer'
    
    keywords=['python', 'swift'],
    classifiers= [
        "Programming Language :: Python :: 3",
        "Operating System :: Linux :: Ubuntu",
    ]
)
