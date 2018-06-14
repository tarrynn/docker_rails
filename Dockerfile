FROM ubuntu:14.04.5

# Centralize here apt setup to just run 'apt-get update' at the beginning instead of
# once before every install command:

RUN apt-get update && apt-get install -y --no-install-recommends wget

RUN sudo echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" >> /etc/apt/sources.list.d/pgdg.list
RUN wget -O pgkey --no-check-certificate https://www.postgresql.org/media/keys/ACCC4CF8.asc
RUN sudo apt-key add pgkey

# Building git from source code:
#   Ubuntu's default git package is built with broken gnutls. Rebuild git with openssl.
##########################################################################
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       python python2.7-dev fakeroot ca-certificates tar gzip zip \
       autoconf automake bzip2 file g++ gcc imagemagick libbz2-dev libc6-dev libcurl4-openssl-dev \
       libdb-dev libevent-dev libffi-dev libgeoip-dev libglib2.0-dev libjpeg-dev libkrb5-dev \
       liblzma-dev libmagickcore-dev libmagickwand-dev libmysqlclient-dev libncurses-dev libpng-dev \
       libpq-dev libreadline-dev libsqlite3-dev libssl-dev libtool libwebp-dev libxml2-dev libxslt-dev \
       libyaml-dev make patch xz-utils zlib1g-dev unzip curl \
    && apt-get -qy build-dep git \
    && apt-get -qy install libcurl4-openssl-dev git-man liberror-perl \
    && mkdir -p /usr/src/git-openssl \
    && cd /usr/src/git-openssl \
    && apt-get source git \
    && cd $(find -mindepth 1 -maxdepth 1 -type d -name "git-*") \
    && sed -i -- 's/libcurl4-gnutls-dev/libcurl4-openssl-dev/' ./debian/control \
    && sed -i -- '/TEST\s*=\s*test/d' ./debian/rules \
    && dpkg-buildpackage -rfakeroot -b \
    && find .. -type f -name "git_*ubuntu*.deb" -exec dpkg -i \{\} \; \
    && rm -rf /usr/src/git-openssl
# Install dependencies by all python images equivalent to buildpack-deps:jessie
# on the public repos.

RUN wget "https://bootstrap.pypa.io/get-pip.py" -O /tmp/get-pip.py \
    && python /tmp/get-pip.py \
    && pip install awscli==1.11.25

ENV RUBY_MAJOR="2.2" \
    RUBY_VERSION="2.2.5" \
    RUBY_DOWNLOAD_SHA256="30c4b31697a4ca4ea0c8db8ad30cf45e6690a0f09687e5d483c933c03ca335e3" \
    RUBYGEMS_VERSION="2.6.12" \
    BUNDLER_VERSION="1.14.6" \
    GEM_HOME="/usr/local/bundle"

ENV BUNDLE_PATH="$GEM_HOME" \
    BUNDLE_BIN="$GEM_HOME/bin" \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_APP_CONFIG="$GEM_HOME"

ENV PATH $BUNDLE_BIN:$PATH

RUN mkdir -p /usr/local/etc \
  && { \
        echo 'install: --no-document'; \
        echo 'update: --no-document'; \
    } >> /usr/local/etc/gemrc \
    && apt-get install -y --no-install-recommends \
       bison libgdbm-dev ruby \
    && wget "https://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.gz" -O /tmp/ruby.tar.gz \
    && echo "$RUBY_DOWNLOAD_SHA256 /tmp/ruby.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/src/ruby \
    && tar -xzf /tmp/ruby.tar.gz -C /usr/src/ruby --strip-components=1 \
    && cd /usr/src/ruby \
  && { \
             echo '#define ENABLE_PATH_CHECK 0'; \
             echo; \
             cat file.c; \
     } > file.c.new \
    && mv file.c.new file.c \
    && autoconf \
    && ./configure --disable-install-doc \
    && make -j"$(nproc)" \
    && make install \
    && apt-get purge -y --auto-remove bison libgdbm-dev ruby \
    && cd / \
    && rm -r /usr/src/ruby \
    && gem update --system "$RUBYGEMS_VERSION" \
    && gem install bundler --version "$BUNDLER_VERSION" \
    && mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
    && chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

RUN apt-get install -y build-essential chrpath libssl-dev libxft-dev libfreetype6 libfreetype6-dev libfontconfig1 libfontconfig1-dev \
    && wget https://github.com/Medium/phantomjs/releases/download/v2.1.1/phantomjs-2.1.1-linux-x86_64.tar.bz2 && sudo tar xvjf phantomjs-2.1.1-linux-x86_64.tar.bz2 \
    && mv phantomjs-2.1.1-linux-x86_64 /usr/local/share \
    && ln -sf /usr/local/share/phantomjs-2.1.1-linux-x86_64/bin/phantomjs /usr/local/bin

RUN apt-get install -y imagemagick libmagickcore-dev \
    && cd /tmp \
    && wget https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs921/ghostscript-9.21.tar.gz \
    && tar xvf ghostscript-9.21.tar.gz \
    && cd ghostscript-9.21 \
    && ./configure --prefix=/usr  --enable-dynamic   --disable-compile-inits --with-system-libtiff \
    && make \
    && make so \
    && sudo make install \
    && sudo make soinstall && install -v -m644 base/*.h /usr/include/ghostscript && ln -v -s ghostscript /usr/include/ps \
    && cd /tmp && wget https://www.imagemagick.org/download/delegates/ghostscript-fonts-std-8.11.tar.gz \
    && tar -xvf ghostscript-fonts-std-8.11.tar.gz -C /usr/share/ghostscript \
    && fc-cache -v /usr/share/ghostscript/fonts/

RUN pip install --upgrade --user awscli \
  && sudo apt-get -y install openssh-client \
  && gem install bundler

RUN wget -O /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 && sudo chmod +x /usr/bin/jq

RUN sudo apt-get -y install postgresql-9.6 postgresql-contrib-9.6

RUN sudo apt-get -y install cmake

# Webpack:
# needed to process the httpS source from above:
RUN apt-get update && apt-get -y install apt-transport-https
RUN curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
RUN sudo apt-get install -y nodejs
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get -y install yarn

# Headless Chrome
RUN apt-get update && apt-get install -y libappindicator1 fonts-liberation libasound2 libnspr4 libnss3 libx11-xcb1 libxss1 xdg-utils libxi6 libgconf-2-4
RUN wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
RUN dpkg -i google-chrome-stable_current_amd64.deb
RUN apt-get update && apt-get install -y chromium-chromedriver
RUN ln -s /usr/lib/chromium-browser/chromedriver /usr/bin/chromedriver

# cleanup:
RUN apt-get clean && rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN gem install bundler

ENV BUNDLE_JOBS=2 \
  BUNDLE_PATH=/bundle

WORKDIR /var/www/html

CMD [ "irb" ]
