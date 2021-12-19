from setuptools import setup, find_packages

# Setting up
setup(
    # the name must match the folder name 'swift'
    name="swift", 
    version="1.0.0",
    author="Philip Turner",
    author_email="philipturner.AR@gmail.com",
    description="Execute Swift code from Python",
    long_description="Allows running Swift code as Python strings in Google Colab",
    packages=find_packages(),
    install_requires=[], # add any additional packages that 
    # need to be installed along with your package. Eg: 'caer'
    
    keywords=['python', 'swift'],
    classifiers= [
        "Programming Language :: Python :: 3",
        "Operating System :: Linux :: Ubuntu",
    ]
)
