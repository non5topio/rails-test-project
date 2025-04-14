FROM ruby:3.1.2 AS test

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  nodejs \
  postgresql-client \
  build-essential \
  libpq-dev

# Set working directory
WORKDIR /app

# Add the app code
COPY . .

# Install gems
RUN bundle install

# Precompile assets (optional for non-API apps)
# RUN bundle exec rake assets:precompile

# Run DB setup (skip if not needed for test env)
RUN bundle exec rails db:prepare

# Run tests and generate lcov report
CMD ["bash", "-c", "bundle exec rails db:test:prepare && COVERAGE=true bundle exec rspec"]

# Expose default Rails port
EXPOSE 3000
