require "minitest/autorun"
require "tempfile"

class TemplateTest < Minitest::Test
  def setup
    system("[ -d test_app ] && rm -rf test_app")
  end

  def teardown
    setup
  end

  def test_generator_succeeds
    output, _err = capture_subprocess_io do
      system("DISABLE_SPRING=1 SKIP_GIT=1 rails new test_app -m template.rb")
    end
    assert_includes output, "Jumpstart app successfully created!"

    output, _err = capture_subprocess_io do
      system("cd test_app && yarn build")
    end
    assert_includes output, "Done in "

    output, _err = capture_subprocess_io do
      system("cd test_app && bin/rails runner 'puts ApplicationController.name'")
    end
    assert $?.success?, "Generated app failed to boot"

    # `bin/dev` runs `bin/jobs`, which dies unless the Solid Queue tables exist.
    output, _err = capture_subprocess_io do
      system("cd test_app && bin/rails db:prepare")
    end
    assert $?.success?, "Generated app failed to prepare its database"

    output, _err = capture_subprocess_io do
      system("cd test_app && bin/rails runner 'exit(SolidQueue::Process.table_exists? ? 0 : 1)'")
    end
    assert $?.success?, "Solid Queue tables missing from the development database"

    output, _err = capture_subprocess_io do
      system("cd test_app && bin/rails runner 'exit(ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::SolidQueueAdapter) ? 0 : 1)'")
    end
    assert $?.success?, "Development Active Job adapter is not Solid Queue"
  end

  # The run above covers the defaults (bootstrap + solid_queue). This one covers the overlay copy,
  # a different CSS toolchain and a non-default scheduler in a single pass.
  def test_generator_with_choices_succeeds
    output, _err = capture_subprocess_io do
      system("DISABLE_SPRING=1 SKIP_GIT=1 SCHEDULER=sidekiq CSS=tailwind rails new test_app -m template.rb")
    end
    assert_includes output, "SCHEDULER: sidekiq"
    assert_includes output, "CSS: tailwind"

    assert_includes File.read("test_app/Procfile"), "worker: bundle exec sidekiq"
    assert_includes File.read("test_app/Procfile.dev"), "worker: bundle exec sidekiq"
    refute File.exist?("test_app/app/helpers/bootstrap_helper.rb"), "Bootstrap helper leaked into the tailwind app"
    refute File.exist?("test_app/lib/tasks/solid_queue.rake"), "Solid Queue's rake task leaked into a sidekiq app"

    navbar = File.read("test_app/app/views/shared/_navbar.html.erb")
    assert_includes navbar, "<details>", "The overlay did not overwrite the navbar"
    refute_includes navbar, "navbar-toggler", "The overlay did not overwrite the navbar"
    assert_includes File.read("test_app/app/helpers/announcements_helper.rb"), "text-green-600"

    output, _err = capture_subprocess_io do
      system("cd test_app && yarn build")
    end
    assert_includes output, "Done in "

    output, _err = capture_subprocess_io do
      system("cd test_app && yarn build:css")
    end
    assert $?.success?, "Tailwind build failed"

    # A class that only exists in the tailwind payload's helper, so it can only reach the
    # stylesheet if Tailwind scanned app/helpers/announcements_helper.rb.
    assert_includes File.read("test_app/app/assets/builds/application.css"), ".text-green-600"

    output, _err = capture_subprocess_io do
      system("cd test_app && bin/rails runner 'puts ApplicationController.name'")
    end
    assert $?.success?, "Generated app failed to boot"

    output, _err = capture_subprocess_io do
      system("cd test_app && bin/rails runner 'exit(ActiveJob::Base.queue_adapter.to_s.include?(\"Sidekiq\") ? 0 : 1)'")
    end
    assert $?.success?, "Active Job adapter is not Sidekiq"

    # `solid_queue:install` writes this line; Thor's `environment` injects above it, so a
    # gsub is the only thing that can override it.
    refute_includes File.read("test_app/config/environments/production.rb"), "queue_adapter = :solid_queue"
  end

  # simple.css is the one option with no build step at all: the stylesheet is a file in the
  # template that Propshaft serves as it is, and the views are the same plain HTML as `none`.
  def test_generator_with_simple_css_succeeds
    output, _err = capture_subprocess_io do
      system("DISABLE_SPRING=1 SKIP_GIT=1 CSS=simple rails new test_app -m template.rb")
    end
    assert_includes output, "CSS: simple"

    assert_includes File.read("test_app/app/assets/stylesheets/simple.css"), "--sans-font",
      "The vendored simple.css did not make it into the app"
    assert_includes File.read("test_app/app/views/layouts/application.html.erb"), 'stylesheet_link_tag "simple"'
    assert_includes File.read("test_app/app/assets/stylesheets/application.css"), ".unread-announcements"
    refute_includes File.read("test_app/Gemfile"), "cssbundling-rails"
    refute_includes File.read("test_app/Procfile.dev"), "css:"
    refute File.exist?("test_app/lib/templates"), "Bootstrap's scaffold templates leaked into a simple.css app"

    output, _err = capture_subprocess_io do
      system("cd test_app && yarn build")
    end
    assert_includes output, "Done in "

    output, _err = capture_subprocess_io do
      system("cd test_app && bin/rails db:prepare")
    end
    assert $?.success?, "Generated app failed to prepare its database"

    output, _err = capture_subprocess_io do
      system("cd test_app && bin/rails runner 'puts ApplicationController.name'")
    end
    assert $?.success?, "Generated app failed to boot"

    Tempfile.create(["render_check", ".rb"]) do |file|
      file.write <<~'RUBY'
        session = ActionDispatch::Integration::Session.new(Rails.application)
        session.host! "localhost"
        %w[/announcements /users/sign_in].each do |path|
          session.get path
          warn "#{path} -> #{session.response.status}" unless session.response.successful?
          exit 1 unless session.response.successful?
        end
        # A digested /assets/simple-<hash>.css means Propshaft resolved the vendored file. Without
        # it the layout raises Propshaft::MissingAssetError instead of rendering.
        exit 1 unless session.response.body.match?(%r{/assets/simple-[^"]+\.css})
      RUBY
      file.flush
      assert system("cd test_app && bin/rails runner #{file.path}"), "A page failed to render"
    end
  end

  # TODO: Fix these tests on CI so they don't fail on db:create
  #
  # def test_generator_with_postgres_succeeds
  #   output, err = capture_subprocess_io do
  #     system("DISABLE_SPRING=1 SKIP_GIT=1 rails new test_app -m template.rb -d postgresql")
  #   end
  #   assert_includes output, "Jumpstart app successfully created!"
  # end

  # def test_generator_with_mysql_succeeds
  #   output, err = capture_subprocess_io do
  #     system("DISABLE_SPRING=1 SKIP_GIT=1 rails new test_app -m template.rb -d mysql")
  #   end
  #   assert_includes output, "Jumpstart app successfully created!"
  # end
end
