# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile supports both ARM (M1/M2/M3/M4) and x86_64 architectures
# Build with: docker build -t tarotapi .
# Run with: docker run -d -p 3000:3000 -e RAILS_MASTER_KEY=<value from config/master.key> --name tarotapi tarotapi

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
FROM ruby:3.4-slim-bookworm AS base

# Architecture detection - informational only, not for validation
RUN arch=$(uname -m) && \
    echo "Building on architecture: $arch"

# install essential packages
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    libpq-dev \
    git \
    pkg-config \
    libyaml-dev \
    curl \
    cmake \
    wget \
    # For native extension compilation
    libclang-dev \
    clang \
    llvm \
    llvm-dev \
    # Add additional dependencies for native gems
    libsqlite3-dev \
    libffi-dev \
    libreadline-dev \
    zlib1g-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    # Install Rust for tokenizers gem
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && echo 'source $HOME/.cargo/env' >> $HOME/.bashrc \
    && /root/.cargo/bin/rustup default stable \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Add cargo to PATH
ENV PATH="/root/.cargo/bin:${PATH}"

# set workdir
WORKDIR /app

# development stage
FROM base AS development

# Set bundle config for platform-specific gems
RUN bundle config set --local force_ruby_platform true

# Install development gems with improved error output
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without '' && \
    bundle install --jobs 4 --retry 3 --full-index || \
    (echo "Bundle install failed, retrying with more verbosity" && \
    bundle install --jobs 4 --retry 3 --verbose)

# copy application code
COPY . .

# configure for development
ENV RAILS_ENV=development \
    RAILS_LOG_TO_STDOUT=true \
    # Connection pool configuration
    RAILS_MAX_THREADS=5 \
    WEB_CONCURRENCY=2 \
    # Makara replica configuration
    DB_REPLICA_ENABLED=false \
    DB_POOL_SIZE=10 \
    # Redis connection pools
    REDIS_POOL_SIZE=15 \
    REDIS_TIMEOUT=2 \
    # Health check credentials
    HEALTH_CHECK_USERNAME=admin

# health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

# builder stage for production
FROM base AS builder

# install gems for production
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local frozen false && \
    bundle config set --local deployment true && \
    bundle config set --local without 'development test' && \
    bundle config set --local force_ruby_platform true && \
    bundle install --jobs 4 --retry 3 && \
    rm -rf ~/.bundle/ /usr/local/bundle/cache

# copy application code
COPY . .

# precompile bootsnap
RUN bundle exec bootsnap precompile app/ lib/

# production stage
FROM ruby:3.4-slim-bookworm AS production

# Architecture detection - informational only, not for validation
RUN arch=$(uname -m) && \
    echo "Building on architecture: $arch"

# install runtime dependencies
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    libpq-dev \
    libyaml-dev \
    curl \
    wget \
    gcc \
    g++ \
    make \
    pkg-config \
    clang \
    libclang-dev \
    llvm \
    libsqlite3-dev \
    libffi-dev \
    libreadline-dev \
    zlib1g-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    echo 'source $HOME/.cargo/env' >> $HOME/.bashrc && \
    /root/.cargo/bin/rustup default stable && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Add cargo to PATH
ENV PATH="/root/.cargo/bin:${PATH}"

# set workdir
WORKDIR /app

# Set environment variables
ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    # Connection pool configuration - more conservative
    RAILS_MAX_THREADS=10 \
    WEB_CONCURRENCY=5 \
    # Makara replica configuration - override these in production
    DB_REPLICA_ENABLED=true \
    DB_PRIMARY_HOST=db-primary \
    DB_PRIMARY_USER=postgres \
    DB_PRIMARY_PORT=5432 \
    DB_REPLICA_HOST=db-replica \
    DB_REPLICA_USER=postgres \
    DB_REPLICA_PORT=5432 \
    DB_POOL_SIZE=20 \
    DB_POOL_TIMEOUT=5 \
    DB_REAPING_FREQUENCY=10 \
    # Redis connection pools
    REDIS_POOL_SIZE=30 \
    REDIS_TIMEOUT=3 

# copy from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app /app

# add non-root user
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails /app

USER rails

# health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

EXPOSE 3000
# Startup command with an initial connection pool check
CMD ["sh", "-c", "bundle exec rake db:pool:healthcheck && bundle exec rails server -b 0.0.0.0"]
