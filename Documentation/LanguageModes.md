# Language Modes

> This documentation page is a work in progress.

Why there needs to be a language mode. Ergonomics when building Swift-Colab, not getting self kicked off of Colab, being able to cache the toolchain and not disconnect and delete the runtime.

Switch modes when restart runtime, but saves the files

Hidden `--swift-colab-dev` mode switches between language modes on every runtime restart. Otherwise, you must change what's in `/opt/swift/runtime` to the desired language.

## Swift

`/opt/swift/runtime` accepts:

After you execute `install_swift.sh` in the Swift-Colab installation command, it instructs you to restart the runtime. Then, it will automatically be in Swift mode.

## Python

`/opt/swift/runtime` accepts:

Needed for Google Drive integration (link to doc file), overcoming a possible bug with Pandas DataFrame presentation (link to doc file about inline graphs)

Explain this link: https://forums.fast.ai/t/python-textfield-output-not-working/51000/14

Include content from this: https://github.com/philipturner/swift-colab/pull/19#issuecomment-1173280812

Change the words saying "Python mode" in the explanation of Colab's free tier, making it a hyperlink to this page.
