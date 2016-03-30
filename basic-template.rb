####################
# Basic template
#
# Copyright 2014 © Tom Dallimore
# MIT Licence
# www.tomdallimore.com
# @tom_dallimore
#
# https://github.com/Jellyfishboy/rails-template  
####################

# Create settings file
inside('config') do
    file 'secrets.example.yml', <<-END
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
    - 2.2.2
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
    file_upload = true
end

if yes?('Do you need to use friendly URLs?')
    gem 'friendly_id', '~> 5.0.0'
    friendly_id = true
end 

if yes?('Do you want to host your assets externally?')
    gem 'asset_sync'
    unless file_upload == true
      gem 'fog' 
      gem 'unf'
    end
    active_sync = true
end

if yes?('Do you want to use Unircon as your rack server?')
    gem 'unicorn', :platforms => :ruby
    unicorn = true
end

if yes?('Do you want to use Capistrano for deployment?')
  capistrano = true
end

gem 'pg'

gem_group :production do
    gem 'unicorn-worker-killer' if unicorn
    gem 'lograge'
end

gem_group :development do
    gem 'better_errors'
    gem 'binding_of_caller'
    gem 'meta_request'
    gem 'quiet_assets'
    gem 'rack-mini-profiler'
    gem 'capistrano', '~> 2.15' if capistrano
    gem 'bullet'
    gem 'capistrano-unicorn', :require => false, :platforms => :ruby if unicorn
    gem 'thin'
    gem 'colorize'
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
    gem 'email_spec'
    gem 'fuubar'
end
gem_group :development, :test do
    gem 'jazz_hands', github: 'nixme/jazz_hands', branch: 'bring-your-own-debugger'
    gem 'pry-byebug'
end

# Performance enhancers
gem 'fast_blank'
gem 'jquery-turbolinks'

# Assets
gem 'compass-rails'

# Logging
gem 'rollbar'

# Scheduled jobs
gem 'whenever', :require => false

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

# Configure Unicorn
# if unicorn
#     inside('config') do
#         file 'unicorn.rb', <<-END
#         root = "/home/app_name/current"
#         # Sample verbose configuration file for Unicorn (not Rack)
#         #
#         # This configuration file documents many features of Unicorn
#         # that may not be needed for some applications. See
#         # http://unicorn.bogomips.org/examples/unicorn.conf.minimal.rb
#         # for a much simpler configuration file.
#         #
#         # See http://unicorn.bogomips.org/Unicorn/Configurator.html for complete
#         # documentation.

#         # Use at least one worker per core if you're on a dedicated server,
#         # more will usually help for _short_ waits on databases/caches.
#         worker_processes 3

#         before_exec do |server|
#           ENV['BUNDLE_GEMFILE'] = "#{root}/Gemfile"
#         end
#         # Since Unicorn is never exposed to outside clients, it does not need to
#         # run on the standard HTTP port (80), there is no reason to start Unicorn
#         # as root unless it's from system init scripts.
#         # If running the master process as root and the workers as an unprivileged
#         # user, do this to switch euid/egid in the workers (also chowns logs):
#         # user "unprivileged_user", "unprivileged_group"

#         # Help ensure your application will always spawn in the symlinked
#         # "current" directory that Capistrano sets up.
#         working_directory root # available in 0.94.0+

#         # listen on both a Unix domain socket and a TCP port,
#         # we use a shorter backlog for quicker failover when busy
#         listen "/tmp/unicorn.app_name.sock", :backlog => 64
#         listen 8080, :tcp_nopush => true

#         # nuke workers after 30 seconds instead of 60 seconds (the default)
#         timeout 30

#         # feel free to point this anywhere accessible on the filesystem
#         pid "#{root}/tmp/pids/unicorn.pid"

#         # By default, the Unicorn logger will write to stderr.
#         # Additionally, ome applications/frameworks log to stderr or stdout,
#         # so prevent them from going to /dev/null when daemonized here:
#         stderr_path "#{root}/log/unicorn.stderr.log"
#         stdout_path "#{root}/log/unicorn.stdout.log"

#         # combine Ruby 2.0.0dev or REE with "preload_app true" for memory savings
#         # http://rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
#         preload_app true
#         GC.respond_to?(:copy_on_write_friendly=) and
#           GC.copy_on_write_friendly = true

#         # Enable this flag to have unicorn test client connections by writing the
#         # beginning of the HTTP headers before calling the application.  This
#         # prevents calling the application for connections that have disconnected
#         # while queued.  This is only guaranteed to detect clients on the same
#         # host unicorn runs on, and unlikely to detect disconnects even on a
#         # fast LAN.
#         check_client_connection false

#         before_fork do |server, worker|
#           # the following is highly recomended for Rails + "preload_app true"
#           # as there's no need for the master process to hold a connection
#           defined?(ActiveRecord::Base) and
#             ActiveRecord::Base.connection.disconnect!

#           # The following is only recommended for memory/DB-constrained
#           # installations.  It is not needed if your system can house
#           # twice as many worker_processes as you have configured.
#           #
#           # # This allows a new master process to incrementally
#           # # phase out the old master process with SIGTTOU to avoid a
#           # # thundering herd (especially in the "preload_app false" case)
#           # # when doing a transparent upgrade.  The last worker spawned
#           # # will then kill off the old master process with a SIGQUIT.
#           # old_pid = "#{server.config[:pid]}.oldbin"
#           # if old_pid != server.pid
#           #   begin
#           #     sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
#           #     Process.kill(sig, File.read(old_pid).to_i)
#           #   rescue Errno::ENOENT, Errno::ESRCH
#           #   end
#           # end
#           #
#           # Throttle the master from forking too quickly by sleeping.  Due
#           # to the implementation of standard Unix signal handlers, this
#           # helps (but does not completely) prevent identical, repeated signals
#           # from being lost when the receiving process is busy.
#           # sleep 1
#         end

#         after_fork do |server, worker|
#           # per-process listener ports for debugging/admin/migrations
#           # addr = "127.0.0.1:#{9293 + worker.nr}"
#           # server.listen(addr, :tries => -1, :delay => 5, :tcp_nopush => true)

#           # the following is *required* for Rails + "preload_app true",
#           defined?(ActiveRecord::Base) and
#             ActiveRecord::Base.establish_connection

#           # if preload_app is true, then you may also want to check and
#           # restart any other shared sockets/descriptors such as Memcached,
#           # and Redis.  TokyoCabinet file handles are safe to reuse
#           # between any number of forked children (assuming your kernel
#           # correctly implements pread()/pwrite() system calls)
#         end
#         END
#     end
# end

# Configure Capistrano
# if capistrano
#     inside('config') do
#         file 'deploy.rb', <<-END
#         set :application, 'app_name'
#         set :user, 'root'
#         set :scm, 'git'
#         set :repository, 'git_repo_url'
#         set :scm_verbose, true
#         set :domain, '0.0.0.0'
#         set :deploy_to, '/home/app_name/'
#         set :branch, 'master'

#         server domain, :app, :web, :db, :primary => true

#         require 'capistrano-unicorn'

#         # Bundler for remote gem installs
#         require "bundler/capistrano"

#         # Only keep the latest 3 releases
#         set :keep_releases, 3
#         after "deploy:restart", "deploy:cleanup"

#         set :normalize_asset_timestamps, false

#         # deploy config
#         set :deploy_via, :remote_cache
#         set :copy_exclude, [".git", ".DS_Store", ".gitignore", ".gitmodules"]
#         set :use_sudo, false

#         # For RBENV
#         set :default_environment, {
#           'PATH' => "$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
#         }

#         namespace :configure do
#           desc "Setup application configuration"
#           task :application, :roles => :app do
#               run "yes | cp /home/configs/settings.yml /home/#{application}/current/config"
#           end
#           desc "Setup database configuration"
#           task :database, :roles => :app do
#             run "yes | cp /home/configs/database.yml /home/#{application}/current/config"
#           end
#           desc "Update crontab configuration"
#           task :crontab, :roles => :app do
#             run "cd /home/#{application}/current && whenever --update-crontab #{application}"
#           end
#         end
#         namespace :database do
#             desc "Migrate the database"
#             task :migrate, :roles => :app do
#               run "cd /home/#{application}/current && RAILS_ENV=#{rails_env} bundle exec rake db:migrate"
#             end
#         end
#         namespace :assets do
#             desc "Install Bower dependencies"
#             task :bower, :roles => :app do
#               run "cd /home/#{application}/current && bower install --allow-root"
#             end 
#             desc "Compile assets"
#             task :compile, :roles => :app do
#                 run "cd /home/#{application}/current && RAILS_ENV=#{rails_env} bundle exec rake assets:precompile"
#             end
#             desc "Generate sitemap"
#             task :refresh_sitemaps do
#               run "cd #{latest_release} && RAILS_ENV=#{rails_env} bundle exec rake sitemap:refresh"
#             end
#         end
#         namespace :rollbar do
#           desc "Notify Rollbar of deployment"
#           task :notify, :roles => :app do
#             set :revision, `git log -n 1 --pretty=format:"%H"`
#             set :local_user, `whoami`
#             set :rollbar_token, ENV['ROLLBAR_ACCESS_TOKEN']
#             rails_env = fetch(:rails_env, 'production')
#             run "curl https://api.rollbar.com/api/1/deploy/ -F access_token=#{rollbar_token} -F environment=#{rails_env} -F revision=#{revision} -F local_username=#{local_user} >/dev/null 2>&1", :once => true
#           end
#         end

#         # additional settings
#         default_run_options[:pty] = true

#         after :deploy, 'configure:application'
#         after 'configure:application', 'configure:database'
#         after 'configure:database', 'configure:crontab'
#         after 'configure:crontab', 'database:migrate'
#         after 'database:migrate', 'assets:bower'
#         after 'assets:bower', 'assets:compile'
#         after 'assets:compile', 'assets:refresh_sitemaps'
#         after 'assets:refresh_sitemaps', 'rollbar:notify'
#         after 'rollbar:notify', 'unicorn:restart'
#         END
#     end
# end

# Configure Devise authentication
if devise
    generate('devise:install') 
    generate('devise User')
end

# Migrate database
rake 'db:migrate'
rake 'db:test:prepare'

# Git
git add: "--all ."
git commit: %Q{ -m 'Finished basic template setup.' }
run 'git push'
