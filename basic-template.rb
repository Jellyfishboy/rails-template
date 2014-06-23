####################
# Basic template
#
# Copyright 2014 © Tom Dallimore
# MIT Licence
# www.tomdallimore.com
# @billy_dallimore
#
# https://github.com/Jellyfishboy/rails-template  
####################

# Create settings file
inside('config') do
file 'settings.yml', <<-END
mailer:
    development:
        server: smtp.example.com
        port: 587
        domain: localhost:3000
        user_name: user@example.com
        password: password123
        host: localhost:3000
    production:
        server: smtp.example.com
        port: 587
        domain: 10.1.2.56
        user_name: user@example.com
        password: password123
        host: 10.1.2.56
aws:
    s3:
        id: abc123
        key: hex123
        bucket: example-bucket
        region: eu-west-1
    cloudfront:
        host:
            carrierwave: http://cdn.example.com
            app: http://cdn%d.example.com
        prefix: /assets
sitemap:
    host: http://www.example.com
rollbar:
    access_token: hex123
email:
    root: http://www.example.com/assets
END
end

# Create CI config
file '.travis.yml', <<-END
language: ruby
rvm:
    - 2.0.0
script:
    - RAILS_ENV=test bundle exec rake db:setup --trace
    - bundle exec rake db:test:prepare
    - bundle exec rspec spec/
END

# Create bower location config file
file '.bowerrc', <<-END
{
    "directory": "vendor/assets/components"
}
END

# Gems
if yes?('Do you need user authentication?')
    gem 'devise'
    gem 'bcrypt-ruby', '~> 3.0.0'
    devise = true
end

if yes?('Do you need a sitemap generator?')
    gem 'sitemap_generator'
    inside('config') do
        file 'sitemap.rb', <<-END
        require 'rubygems'
        require 'sitemap_generator'

        # Set the host name for URL creation
        SitemapGenerator::Sitemap.default_host = Settings.sitemap.host
        SitemapGenerator::Sitemap.sitemaps_path = 'shared/'

        SitemapGenerator::Sitemap.create do

        end
        SitemapGenerator::Sitemap.ping_search_engines
        END
    end
end

if yes?('Do you need to use file uploads?')
    gem 'mini_magick'
    gem 'carrierwave'
    gem 'fog'
    gem 'unf'
end

if yes?('Do you need to use friendly URLs?')
    gem 'friendly_id', '~> 5.0.0'
    friendly_id = true
end 

if yes?('Do you want to host your assets externally?')
    gem 'asset_sync'
    active_sync = true
end

gem 'unicorn', :platforms => :ruby
gem 'rollbar', '~> 0.12.17'
gem 'whenever', :require => false
gem 'compass-rails'
gem 'pg'

gem_group :production do
  gem 'lograge'
end

gem_group :development do
    gem 'better_errors'
    gem 'binding_of_caller'
    gem 'meta_request'
    gem 'haml-rails'
    gem 'quiet_assets'
    gem 'rack-mini-profiler'
    gem 'capistrano', '~> 2.15'
    gem 'bullet'
    gem 'haml'
    gem 'capistrano-unicorn', :require => false, :platforms => :ruby
end
gem_group :test do
    gem 'rspec-rails'
    gem 'factory_girl_rails'
    gem 'capybara'
    gem 'capybara-screenshot'
    gem 'poltergeist'
    gem 'database_cleaner'
    gem 'shoulda-matchers'
    gem 'faker'
end
gem_group :development, :test do
    gem 'pry'
    gem 'sqlite3'
end
run 'bundle install'

# Setup gems
generate('friendly_id') if friendly_id
generate('asset_sync:install --provider=AWS') if active_sync
generate('rspec:install')
generate('rollbar')

# Remove redundant files
run 'rm -rf test'

# Configure rspec
run 'mkdir spec/support'
inside('spec/support') do
file 'web_driver.rb', <<-END
RSpec.configure do |config|
  config.before :suite, js: :true do
      require 'capybara/poltergeist'
      Capybara.register_driver :poltergeist do |app|
        Capybara::Poltergeist::Driver.new(app, {
          js_errors: true,
          inspector: true,
          phantomjs_options: ['--load-images=no', '--ignore-ssl-errors=yes'],
          timeout: 120
        })
      end
  end

  config.before :each, js: :true do
    Capybara.current_driver = :poltergeist
  end
end
END
end
inside('spec/support') do
file 'database_cleaner.rb', <<-END
RSpec.configure do |config|

  # Before running the test suite, clear the test database completely.
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  # Sets the default database cleaning strategy to be transactions. Transactions are alot faster.
  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  # Only runs on examples which have been flagged with ':js => true'. Used for capybara and selenium for integration testing. These types of tests wont
  # work with transactions, so sets the database strategy as truncation.
  config.before(:each, :js => true) do
    DatabaseCleaner.strategy = :truncation
  end

  # Execute the aforementioned cleanup strategy before and after.
  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
END
end

# Configure devise authentication
generate('devise:install') if devise
generate('devise User') if devise

# Migrate database
rake 'db:migrate'
rake 'db:test:prepare'

# Git
git add: "--all ."
git commit: %Q{ -m 'Finished basic template setup.' }
run 'git push'
