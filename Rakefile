require 'rake'

ROOT_DIR       = __dir__
VERSION_FILE   = File.join(ROOT_DIR, 'lib', 'spree_storefront', 'version.rb')
GEM_NAMES      = %w[spree_storefront spree_page_builder].freeze
VERSION_REGEXP = /VERSION\s*=\s*['"]([^'"]+)['"]/

def current_version
  File.read(VERSION_FILE) =~ VERSION_REGEXP && Regexp.last_match(1) or
    abort "Could not read VERSION from #{VERSION_FILE}"
end

def sh!(cmd, chdir: ROOT_DIR)
  puts "$ #{cmd}  (in #{chdir})"
  Dir.chdir(chdir) { system(cmd) or abort("command failed: #{cmd}") }
end

namespace :release do
  desc 'Bump the shared version file. TARGET = patch|minor|major|pre|x.y.z (default: patch)'
  task :bump, [:target] do |_, args|
    target = args[:target] || 'patch'

    # Bump the shared version file exactly once. We invoke `gem bump` inside
    # storefront/ (any gem dir would do) with --file pointing at the
    # repo-root version file. --no-commit because we create a single commit
    # from the repo root afterwards so history stays at the top level.
    sh! "gem bump --version #{target} --file #{VERSION_FILE} --no-commit",
        chdir: File.join(ROOT_DIR, 'storefront')

    new_version = current_version
    puts "Bumped to #{new_version}"

    sh! "git add #{VERSION_FILE}"
    sh! %(git commit -m "Bump version to #{new_version}")
  end

  desc 'Build and push both gems to rubygems.org, then tag and push the tag'
  task :publish do
    version = current_version

    # Name the gems explicitly rather than using `--recurse`. A recursive
    # run would also visit every *.gemspec under vendor/bundle/ and try to
    # republish hundreds of third-party gems to rubygems.org.
    sh! "gem release #{GEM_NAMES.join(' ')}"

    # One tag covers both gems since they share a version.
    tag = "v#{version}"
    sh! "git tag -a #{tag} -m 'Release #{tag}'"
    sh! "git push origin #{tag}"
    sh! 'git push'
  end
end

desc 'Bump the shared version and publish both gems. TARGET = patch|minor|major|pre|x.y.z (default: patch)'
task :release, [:target] do |_, args|
  Rake::Task['release:bump'].invoke(args[:target] || 'patch')
  Rake::Task['release:publish'].invoke
end

desc 'Print the current shared version'
task :version do
  puts current_version
end
