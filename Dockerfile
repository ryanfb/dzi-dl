FROM ruby:2.3

RUN apt-get update && apt-get install -y wget imagemagick

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

VOLUME ["/data"]

WORKDIR /data

ENTRYPOINT ["/usr/src/app/dzi-dl.rb"]