require "fileutils"
require "shellwords"

# Copied from: https://github.com/mattbrictson/rails-template
# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    require "tmpdir"
    source_paths.unshift(tempdir = Dir.mktmpdir("jumpstart-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git clone: [
      "--quiet",
      "https://github.com/excid3/gorails-app-template.git",
      tempdir
    ].map(&:shellescape).join(" ")

    if (branch = __FILE__[%r{gorails-app-template/(.+)/template.rb}, 1])
      Dir.chdir(tempdir) { git checkout: branch }
    end
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def rails_version
  Gem::Version.new(Rails::VERSION::STRING)
end

def rails_8_or_newer?
  Gem::Requirement.new(">= 8.0.0.alpha").satisfied_by? rails_version
end

unless rails_8_or_newer?
  say "\nJumpstart requires Rails 8 or newer. You are using #{rails_version}.", :green
  say "Please remove partially installed Jumpstart files #{original_app_name} and try again.", :green
  exit 1
end

# Pick one of `choices`. ENV wins so CI and reruns stay non-interactive, otherwise ask.
# Thor's `ask` returns nil when stdin is closed (CI, a scripted `rails new`) rather than the
# default, and `limited_to:` would spin forever in that case, so the fallback happens here.
def choose(key, question, choices, default)
  answer = ENV[key] || ask("#{question} [#{choices.join("/")}]", default: default) || default
  answer = answer.to_s.strip.downcase
  answer = default unless choices.include?(answer)
  say "  #{key}: #{answer}", :green
  answer
end

def ask_questions
  say "\nBase install: every package is added by default.", :blue
  say "Preset either answer with SCHEDULER=... CSS=... TESTING=...\n"

  @scheduler = choose("SCHEDULER", "Which job scheduler?", %w[solid_queue sidekiq none], "solid_queue")
  @css = choose("CSS", "Which CSS framework?", %w[bootstrap tailwind simple none], "bootstrap")
  @testing = choose("TESTING", "Which testing framework?", %w[minitest rspec none], "minitest")
end

# Bootstrap and Tailwind are installed through cssbundling-rails, so they need a build step, a
# `css:` foreman process, and scaffold templates. simple.css and none are plain files that Propshaft
# serves as they are, and simple.css being classless means Rails' own scaffolds already look right.
def css_build?
  !%w[none simple].include?(@css)
end

def add_gems
  add_gem 'cssbundling-rails' if css_build?
  add_gem 'devise', '~> 5.0'
  add_gem 'friendly_id', '~> 5.7'
  add_gem 'madmin'
  add_gem 'name_of_person', '~> 1.1'
  add_gem 'noticed', '~> 3.0'
  add_gem 'omniauth-facebook', '~> 11.0'
  add_gem 'omniauth-github', '~> 2.0'
  add_gem 'pretender', '~> 1.0'
  add_gem 'pundit', '~> 2.5'
  add_gem 'rspec-rails', group: %i[development test] if @testing == "rspec"
  add_gem 'sidekiq' if @scheduler == "sidekiq"
  add_gem 'sitemap_generator', '~> 7.0'
end

def set_application_name
  # Add Application Name to Config
  environment "config.application_name = Rails.application.class.module_parent_name"

  # Announce the user where they can change the application name in the future.
  puts "You can change application name inside: ./config/application.rb"
end

def use_solid_queue_in_development
  # Without this, Active Job uses Rails' inline :async adapter and Procfile.dev's `bin/jobs`
  # never sees a job. Development Solid Queue has no `connects_to`, so it uses the primary
  # database, where lib/tasks/solid_queue.rake loads the queue tables during db:prepare.
  environment "config.active_job.queue_adapter = :solid_queue", env: "development"
end

# The command the worker process runs, or nil when the choice is to have no worker at all.
def worker_command
  {"solid_queue" => "bin/jobs", "sidekiq" => "bundle exec sidekiq"}[@scheduler]
end

# `solid_queue:install` turns production.rb's commented-out adapter line into
# `config.active_job.queue_adapter = :solid_queue`, and Thor's `environment` injects at the *top*
# of the `configure do` block, so an injected line would lose to it. Gsub instead.
def set_queue_adapter(adapter)
  gsub_file "config/environments/production.rb",
            "config.active_job.queue_adapter = :solid_queue",
            "config.active_job.queue_adapter = :#{adapter}"
  environment "config.active_job.queue_adapter = :#{adapter}", env: "development"
end

def configure_scheduler
  case @scheduler
  when "solid_queue" then use_solid_queue_in_development
  when "sidekiq"     then set_queue_adapter("sidekiq")
  when "none"        then set_queue_adapter("async")
  end

  command = worker_command
  %w[Procfile Procfile.dev].each do |procfile|
    gsub_file procfile, /^worker: .*\n/, command ? "worker: #{command}\n" : ""
  end
end

def configure_testing
  case @testing
  when "rspec"
    generate "rspec:install"
  when "none"
    remove_dir "test"
  end
end

def add_users
  route "root to: 'home#index'"
  generate "devise:install"

  generate :devise, "User", "first_name", "last_name", "announcements_last_read_at:datetime", "admin:boolean"

  # Set admin default to false
  gsub_file Dir.glob("db/migrate/*_create_users.rb").first, /:admin/, ":admin, default: false"

  inject_into_file("app/models/user.rb", "omniauthable, :", after: "devise :")
end

def add_authorization
  generate 'pundit:install'
end

def add_javascript
  run "yarn add esbuild esbuild-rails chokidar local-time @hotwired/stimulus @hotwired/turbo-rails @rails/activestorage"
end

def copy_templates
  # Rails' stylesheet is what Propshaft serves when there is no build step to produce one.
  remove_file "app/assets/stylesheets/application.css" if css_build?
  remove_file "app/javascript/application.js"
  remove_file "app/javascript/controllers/index.js"
  remove_file "Procfile.dev"

  copy_file "Procfile"
  copy_file "Procfile.dev"
  copy_file ".foreman"
  copy_file "esbuild.config.mjs"
  copy_file "app/javascript/application.js"
  copy_file "app/javascript/controllers/index.js"

  # `app/` is the Bootstrap payload. The other frameworks are overlays copied over the top of it,
  # so every file under them must be complete: anything an overlay omits keeps Bootstrap classes.
  # Thor's `directory` defaults its destination to the source path, hence the explicit ".".
  # simple.css styles the same plain HTML as `none`, so it reuses that overlay and adds its own.
  directory "app", force: true
  directory "test", force: true if @testing == "minitest"
  directory "lib/tasks", force: true if @scheduler == "solid_queue"
  directory "lib/templates", force: true if css_build?
  directory "variants/#{@css == "simple" ? "none" : @css}", ".", force: true unless @css == "bootstrap"
  directory "variants/simple", ".", force: true if @css == "simple"

  unless @css == "bootstrap"
    remove_file "app/helpers/bootstrap_helper.rb"
    remove_file "app/assets/stylesheets/jumpstart"
  end

  gsub_file "Procfile.dev", /^css: .*\n/, "" unless css_build?

  # No "directory \"config\"" here: this template ships no config payload, and Thor would
  # fall back to Rails' own config templates, overwriting the app's config (cable.yml, etc.)

  route "get '/terms', to: 'home#terms'"
  route "get '/privacy', to: 'home#privacy'"
end

def add_announcements
  generate "model Announcement published_at:datetime announcement_type name description:text"
  route "resources :announcements, only: [:index]"
end

def add_notifications
  rails_command "noticed:install:migrations"
  route "resources :notifications, only: [:index]"
end

def add_multiple_authentication
  insert_into_file "config/routes.rb", ', controllers: { omniauth_callbacks: "users/omniauth_callbacks" }', after: "  devise_for :users"

  generate "model Service user:references provider uid access_token access_token_secret refresh_token expires_at:datetime auth:text"

  template = """
  env_creds = Rails.application.credentials[Rails.env.to_sym] || {}
  %i{ facebook github }.each do |provider|
    if options = env_creds[provider]
      config.omniauth provider, options[:app_id], options[:app_secret], options.fetch(:options, {})
    end
  end
  """.strip

  insert_into_file "config/initializers/devise.rb", "  " + template + "\n\n", before: "  # ==> Warden configuration"
end

def add_friendly_id
  generate "friendly_id"
end

def add_sitemap
  rails_command "sitemap:install"
end

def add_css
  return unless css_build?

  rails_command "css:install:#{@css}"
end

def add_announcements_css
  case @css
  when "bootstrap"
    insert_into_file 'app/assets/stylesheets/application.bootstrap.scss', '@import "jumpstart/announcements";'
  when "none", "simple"
    # No build step, so Propshaft serves Rails' own stylesheet as-is. Same two rules, with the
    # Bootstrap sass variables replaced by the hex values they resolve to. The last three revive
    # the announcement type classes, which the plain views still emit and only Bootstrap used to
    # style: #b45309 instead of Bootstrap's #ffc107, which is unreadable on a white background.
    append_to_file "app/assets/stylesheets/application.css", <<~CSS
      .announcement strong { color: #495057; font-weight: 900; }
      .unread-announcements::before { content: ""; display: inline-block; width: 8px; height: 8px; margin-right: 6px; border-radius: 50%; background: #dc3545; }
      .text-success { color: #198754; }
      .text-warning { color: #b45309; }
      .text-danger { color: #dc3545; }
    CSS
  end
  # tailwind: the two rules are utility classes in the tailwind helper and views
end

def add_esbuild_script
  run %(npm pkg set scripts.build="node esbuild.config.mjs")
  run "yarn build"
end

def add_gem(name, *options)
  gem(name, *options) unless gem_exists?(name)
end

def gem_exists?(name)
  IO.read("Gemfile") =~ /^\s*gem ['"]#{name}['"]/
end

# Main setup
add_template_repository_to_source_path
ask_questions
add_gems

after_bundle do
  set_application_name
  add_users
  add_authorization
  add_javascript
  add_announcements
  add_notifications
  add_multiple_authentication
  add_friendly_id
  add_css
  add_sitemap
  add_announcements_css
  rails_command "active_storage:install"

  # Make sure Linux is in the Gemfile.lock for deploying
  run "bundle lock --add-platform x86_64-linux"

  copy_templates
  configure_scheduler
  configure_testing

  add_esbuild_script

  # Commit everything to git
  unless ENV["SKIP_GIT"]
    git :init
    git add: "."
    # git commit will fail if user.email is not configured
    begin
      git commit: %( -m 'Initial commit' )
    rescue StandardError => e
      puts e.message
    end
  end

  say
  say "Jumpstart app successfully created!", :blue
  say
  say "To get started with your new app:", :green
  say "  cd #{original_app_name}"
  say
  say "  # Update config/database.yml with your database credentials"
  say
  say "  bin/rails db:prepare"
  say "  bin/rails g madmin:install # Generate admin dashboards"
  say "  gem install foreman"
  say "  bin/dev"
  say
  say "  scheduler: #{@scheduler}, css: #{@css}, testing: #{@testing}"
end
