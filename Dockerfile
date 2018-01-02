FROM yastdevel/ruby:sle12-sp3
RUN zypper --non-interactive update yast2
COPY . /usr/src/app

