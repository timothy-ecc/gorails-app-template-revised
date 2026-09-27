### 2026-09-27

* Upgrade to Rails 8.1 support and modernize for Propshaft/Solid Stack
* Replace Sidekiq with Solid Queue (worker now `bin/jobs`); remove Redis from Cable
* Remove Twitter OmniAuth; keep only Facebook and GitHub providers
* Remove broken impersonation feature (no longer available in current dependencies)
* Remove `github/workflows/verify.yml` (Rails 8 generates a complete CI workflow)
* Upgrade gem pins: Devise ~> 5.0, Noticed ~> 3.0, SitemapGenerator ~> 7.0, Pretender ~> 1.0, FriendlyId ~> 5.7, Pundit ~> 2.5, omniauth-facebook ~> 11.0, omniauth-github ~> 2.0, name_of_person ~> 1.1
* Remove jsbundling-rails dependency (esbuild config is bundled); drop unused Rails UJS/trix packages
* Make Devise 5/OmniAuth links Turbo-safe (`button_to` with `data: { turbo: false }`)
* Fix Turbo-safe destroy links in registrations
* Switch scaffold show template to Bootstrap 5; clean navbar (use Bootstrap Icons)
* Remove Font Awesome CDN from head
* Remove `app/assets/config/manifest.js` (Propshaft)
* Update CI to Ruby 3.4, actions/checkout@v6, actions/setup-node@v4
* Update README for Rails 8, Solid Queue, no Redis/Spring
* Drop `whenever` (no long-running clock process); keep cron usage as opt-in if needed later
* Add the `esbuild` npm package (the bundled `esbuild.config.mjs` needs it; `yarn build` failed without it)
* Stop copying a `config` directory: with no payload there, Thor fell back to Rails' own config
  templates and overwrote the generated app's config (putting Redis back into `cable.yml`)
* Load Solid Queue's schema into the development database on `db:prepare`/`db:setup`; Rails only
  configures a separate `queue:` database for production, so `bin/dev`'s worker died with
  `Could not find table 'solid_queue_processes'`
* Set `config.active_job.queue_adapter = :solid_queue` in development so `Procfile.dev`'s
  `bin/jobs` actually processes jobs instead of polling an empty queue
* Ship `test/fixtures/users.yml` with unique emails so `fixtures :all` no longer violates the
  unique index on `users.email` (every DB-touching test in a generated app errored)
* Scaffold `_form` Destroy link now uses Turbo (`turbo_method`/`turbo_confirm`) instead of rails-ujs

### 2021-12-27

* Support Rails 7.0
* Drop support for Rails 5.2 and earlier

### 2021-05-13

* Upgrade to Bootstrap 5
* Remove data-confirm-modal, not yet bootstrap 5 compatible
* Drop jQuery
* Include devise views directly

### 2021-03-04

* Switch to Madmin for admin area

### 2020-10-24

* Rescue from git configuration exception

### 2020-08-20

* Add tests for generating postgres and mysql apps

### 2020-08-07

* Refactor notifications to use the [Noticed gem](https://github.com/excid3/noticed)

### 2019-02-28

* Adds support for Rails 6.0
* Move all Javascript to Webpacker for Rails 5.2 and 6.0
  * Use Bootstrap, data-confirm-modal, and local-time from NPM packages
  * ProvidePlugin sets jQuery, $, and Rails variables for webpacker
* Use https://github.com/excid3/administrate fork of Administrate
  * Adds fix for zeitwerk autoloader in Rails 6
  * Adds support for virtual attributes
* Add Procfile, Procfile.dev and .foreman configs
* Add welcome message and instructions after completion

### 2019-01-02 and before

* Original version of Jumpstart
* Supported Rails 5.2 only
