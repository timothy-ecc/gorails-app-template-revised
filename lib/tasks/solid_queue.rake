# Rails only configures a separate queue database for production, so in development Solid Queue
# uses the primary database, which never gets Solid Queue's tables. Load them alongside the app's
# own schema so `bin/jobs` works after `db:prepare`.
#
# Skip this when the app configures `config.solid_queue.connects_to` (production, or a development
# `queue:` database): `db:prepare` already loads `db/queue_schema.rb` into that separate database.
namespace :solid_queue do
  desc "Load the Solid Queue schema into the primary database (development/test)"
  task load_schema: :environment do
    if SolidQueue.connects_to.blank? && !SolidQueue::Process.table_exists?
      load Rails.root.join("db/queue_schema.rb")
    end
  end
end

# `enhance` with a block, not a prerequisite, so this runs after the database exists.
# `db:setup` is included because `db:reset` runs `db:drop` + `db:setup`.
%w[db:prepare db:setup].each do |name|
  next unless Rake::Task.task_defined?(name)

  Rake::Task[name].enhance { Rake::Task["solid_queue:load_schema"].invoke }
end
