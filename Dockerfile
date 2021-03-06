FROM ruby:latest

RUN apt-get update && apt-get install -y imagemagick

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

VOLUME ["/data"]

WORKDIR /data

ENTRYPOINT ["/usr/src/app/dzi-dl.rb"]
