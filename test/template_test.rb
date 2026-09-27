require "minitest/autorun"

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
