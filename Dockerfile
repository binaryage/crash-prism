MAINTAINER Antonin Hildebrand "antonin@binaryage.com"

FROM ubuntu

# make sure the package repository is up to date
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update

# install dependencies
RUN apt-get install -y ruby1.9.3 git make g++
RUN gem install bundler

# http://debuggable.com/posts/disable-strict-host-checking-for-git-clone:49896ff3-0ac0-4263-9703-1eae4834cda3
RUN mkdir /root/.ssh && echo "Host github.com\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config

# deploy prism
ADD . /prism
RUN cd /prism && bundle install --system
RUN ln -s /prism/bin/prism /usr/local/bin/prism && chmod +x /usr/local/bin/prism

# expose prism port
EXPOSE 3999

# launch server when running container
CMD ["prism", "serve", "--port", "3999", "--token", "$GITHUB_TOKEN", "--workspace", "/prism/workspace"]