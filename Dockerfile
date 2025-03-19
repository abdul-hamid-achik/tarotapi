# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t tarot_api .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name tarot_api tarot_api

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
FROM ruby:3.4-slim-bookworm AS base

# install essential packages
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    libpq-dev \
    git \
    pkg-config \
    libyaml-dev \
    curl && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# set workdir
WORKDIR /app

# development stage
FROM base AS development

# install development gems before copying application code
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without '' && \
    bundle install --jobs 4 --retry 3

# copy application code
COPY . .

# configure for development
ENV RAILS_ENV=development \
    RAILS_LOG_TO_STDOUT=true

# health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

# builder stage for production
FROM base AS builder

# install gems for production
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment true && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3 && \
    rm -rf ~/.bundle/ /usr/local/bundle/cache

# copy application code
COPY . .

# precompile bootsnap
RUN bundle exec bootsnap precompile app/ lib/

# production stage
FROM ruby:3.4-slim-bookworm AS production

# install runtime dependencies
RUN apt-get update -qq && \
    apt-get install -y \
    libpq-dev \
    libyaml-dev \
    curl && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# set workdir
WORKDIR /app

# copy from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app

# add non-root user
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails /app

USER rails

# configure rails
ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

# health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
