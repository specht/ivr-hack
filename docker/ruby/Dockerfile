FROM ruby:3-buster

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y bash ruby-dev imagemagick tzdata sox python3 && rm -rf /var/cache/apt/*
RUN cp /usr/share/zoneinfo/Europe/Berlin /etc/localtime && echo "Europe/Berlin" > /etc/timezone
RUN gem install bundler
ADD Gemfile /
RUN bundle install
RUN useradd -u 1000 michael
USER michael
