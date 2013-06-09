# Crash PRISM

**Crash PRISM** is a custom command-line tool and a web server for symbolizing crash dumps of our apps from BinaryAge.

It is NOT a secret electronic surveillance program, formally classified as top secret, that has been run by the United States National Security Agency (NSA) since 2007.

### Installation

    git clone git@github.com:binaryage/crash-prism.git
    cd crash-prism
    bundle install
    bundle exec bin/prism sym some/path/to/Finder.crash
    bundle exec bin/prism show <gist-sha>

### Build docker container

    cd crash-prism
    docker build -t "prism" .
    PRISM=$(docker run -d -e GITHUB_TOKEN=deadbeef prism)

    docker port $PRISM 3999
    docker logs $PRISM
    docker kill $PRISM
    ...

#### License: [MIT](https://raw.github.com/binaryage/crash-prism/master/license.txt)