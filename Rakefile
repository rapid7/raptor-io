require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'yard'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

#
# load rake files like a normal rails app
# @see http://viget.com/extend/rails-engine-testing-with-rspec-capybara-and-factorygirl
#

pathname = Pathname.new(__FILE__)
root = pathname.parent
rakefile_glob = root.join('lib', 'tasks', '**', '*.rake').to_path

Dir.glob(rakefile_glob) do |rakefile|
  load rakefile
end
