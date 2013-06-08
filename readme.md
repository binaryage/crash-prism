# Crash PRISM

**Crash PRISM** is a custom command-line tool and a web server for symbolizing crash dumps of our apps from BinaryAge.

It is NOT a secret electronic surveillance program, formally classified as top secret, that has been run by the United States National Security Agency (NSA) since 2007.

### Installation

    git clone git@github.com:binaryage/crash-prism.git
    cd crash-prism
    bundle install
    bin/prism sym some/path/to/Finder.crash
    bin/prism show <gist-sha>

#### License: [MIT](https://raw.github.com/binaryage/crash-prism/master/license.txt)