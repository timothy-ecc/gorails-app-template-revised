> [!IMPORTANT]
> 👉 This has evolved into [Jumpstart Pro](https://jumpstartrails.com), a Rails template that includes payments, team accounts, TailwindCSS, APIs, Hotwire Native, and much, much more.
> Check it out at https://jumpstartrails.com

# GoRails App Template

A Rails 8.1+ application template. It generates a working app with accounts, an admin panel, background jobs and a Bootstrap 5 front end already wired together — no Redis, no Sidekiq, no webpacker. Run it once and you have something to build on instead of a folder of boilerplate.

#### What's included

**Stack** — Rails 8.1+, Propshaft, Importmap + Stimulus + Turbo, Active Storage, esbuild for JavaScript (with hot reload) and cssbundling-rails for CSS, Bootstrap 5 with Bootstrap Icons.

**No Redis** — background jobs run on [Solid Queue](https://github.com/rails/solid_queue) (`bin/jobs`), caching on Solid Cache and Action Cable on Solid Cable. Production gives each its own database.

**Accounts** — Devise 5 with email and password plus Facebook and GitHub sign-in, read from encrypted credentials per environment, with each user's tokens kept in `Service`. Every user has a name, an avatar (Active Storage variant, Gravatar fallback) and an `admin` flag.

**Authorization** — Pundit, plus the [madmin](https://github.com/excid3/madmin) admin panel (`rails g madmin:install`), linked from the navbar for admins.

**Product starter** — "What's New" announcements with unread tracking, an in-app notifications inbox via `noticed`, and `pretender` for signing in as another user while developing.

**CRUD that looks right** — Bootstrap 5 scaffold templates, so `rails g scaffold` hands you styled index, form and show pages.

**Pages** — a responsive navbar with account and notification menus, a home page, and `/terms` and `/privacy` routes.

**Dev & deploy** — `bin/dev` runs the web server, the job worker and the JS/CSS watchers; a `Procfile` runs the same two processes in production. A GitHub Actions workflow generates a throwaway app and checks it builds and boots.

#### Requirements

You'll need the following installed to run the template successfully:

* Ruby 3.2 or higher
* bundler - `gem install bundler`
* rails - `gem install rails` (Rails 8 or newer)
* Database - we recommend Postgres, but you can use MySQL, SQLite3, etc
* ImageMagick or libvips for ActiveStorage variants
* Yarn - `brew install yarn` or [Install Yarn](https://yarnpkg.com/en/docs/install)
* Foreman - `gem install foreman` - `bin/dev` uses it to run all your processes in development

#### Creating a new app

```bash
rails new myapp -d postgresql -m https://raw.githubusercontent.com/excid3/gorails-app-template/master/template.rb
```

Or if you have downloaded this repo, you can reference template.rb locally:

```bash
rails new myapp -d postgresql -m template.rb
```

#### Running your app

Set up the database first:

```bash
bin/rails db:prepare
```

This also creates Solid Queue's tables, which the job worker (`bin/jobs`) needs. Development
runs jobs through Solid Queue, so start the app with `bin/dev` rather than `bin/rails server`
alone -- otherwise jobs sit in the queue until a worker is running.

Then start the web server, the job worker, and the asset watchers:

```bash
bin/dev
```

You can also run them in separate terminals manually if you prefer.

A `Procfile` is generated for production too — it runs the web server and the Solid Queue worker.

#### Authenticate with social networks

We use the encrypted Rails Credentials for app_id and app_secret when it comes to omniauth authentication. Edit them as so:

```
EDITOR=vim rails credentials:edit
```

Make sure your file follows this structure:

```yml
secret_key_base: [your-key]
development:
  facebook:
    app_id: something
    app_secret: something
    options:
      scope: 'user:email'
      whatever: true
  github:
    app_id: something
    app_secret: something
    options:
      scope: 'user:email'
      whatever: true
production:
  facebook:
    app_id: something
    app_secret: something
    options:
      scope: 'user:email'
      whatever: true
  github:
    app_id: something
    app_secret: something
    options:
      scope: 'user:email'
      whatever: true
```

With the environment, the service and the app_id/app_secret. If this is done correctly, you should see login links
for the services you have added to the encrypted credentials using `EDITOR=vim rails credentials:edit`

#### Enabling Admin Panel
App uses `madmin` [gem](https://github.com/excid3/madmin), so you need to run the madmin generator:

```
rails g madmin:install
```

This will install Madmin and generate resources for each of the models it finds.

#### Cleaning up

```bash
bin/rails db:drop
cd ..
rm -rf myapp
```
