# Swift-Colab

Status: Incomplete

This is only public to allow downloading files on Google Colab. Do not rely on this for guidance on using Swift on Google Colab yet.

How to run Swift on Google Colab through command line:

```bash
!curl https://raw.githubusercontent.com/philipturner/swift-colab/main/install_swift.sh --output install_swift.sh && bash install_swift.sh
```

<!--
```bash
!mkdir /swift && cd /swift && curl https://download.swift.org/swift-5.5.2-release/ubuntu1804/swift-5.5.2-RELEASE/swift-5.5.2-RELEASE-ubuntu18.04.tar.gz --output toolchain-zipped

!cd /swift && tar -xvzf toolchain-zipped -C /swift

!cd /swift && rm toolchain-zipped && mv swift-5.5.2-RELEASE-ubuntu18.04 toolchain

!mkdir /projects && cd /projects && mkdir Hello

!export PATH="/swift/toolchain/usr/bin:$PATH" && cd /projects/Hello && swift package init && swift build
```
-->
