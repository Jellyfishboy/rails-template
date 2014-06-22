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
    generate('friendly_id')
end 

if yes?('Are you hosting your assets externally?')
    gem 'asset_sync'
end

gem 'unicorn', :platforms => :ruby
gem 'rollbar', '~> 0.12.17'
gem 'whenever', :require => false
gem 'pg'
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
bundle install

# Setup Rspec
generate('rspec:install')

# Setup rollbar
generate('rollbar')

# Git
git add: "."
git commit: %Q{ -m 'Finished basic template setup.' }