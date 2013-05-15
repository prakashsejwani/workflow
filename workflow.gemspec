# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'workflow/version'

Gem::Specification.new do |gem|
  gem.name          = "workflow"
  gem.version       = Workflow::VERSION
  gem.authors       = ["Vladimir Dobriakov"]
  gem.email         = ["vladimir@geekq.net"]
  gem.description = "    Workflow is a finite-state-machine-inspired API for modeling and interacting\n    with what we tend to refer to as 'workflow'.\n\n    * nice DSL to describe your states, events and transitions\n    * robust integration with ActiveRecord and non relational data stores\n    * various hooks for single transitions, entering state etc.\n    * convenient access to the workflow specification: list states, possible events\n      for particular state\n"
  gem.summary       = %q{A replacement for acts_as_state_machine.}
  gem.homepage = "http://www.geekq.net/workflow/"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.extra_rdoc_files = [
    "README.markdown"
  ]

  gem.required_rubygems_version = Gem::Requirement.new(">= 0") if gem.respond_to? :required_rubygems_version=
  gem.authors = ["Vladimir Dobriakov", "svs"]
  gem.date = %q{2011-08-20}
  gem.description = %q{    Workflow is a finite-state-machine-inspired API for modeling and interacting
    with what we tend to refer to as 'workflow'.

    * nice DSL to describe your states, events and transitions
    * robust integration with ActiveRecord and non relational data stores
    * various hooks for single transitions, entering state etc.
    * convenient access to the workflow specification: list states, possible events
      for particular state
}
  gem.email = %q{vladimir@geekq.net svs@svs.io}
  gem.extra_rdoc_files = [
    "README.markdown"
  ]
  gem.files = [
    "MIT-LICENSE",
    "README.markdown",
    "Rakefile",
    "VERSION",
    "lib/workflow.rb",
    "test/advanced_hooks_and_validation_test.rb",
    "test/before_transition_test.rb",
    "test/couchtiny_example.rb",
    "test/main_test.rb",
    "test/multiple_workflows_test.rb",
    "test/readme_example.rb",
    "test/test_helper.rb",
    "test/without_active_record_test.rb",
    "spec/spec_helper.rb",
    "spec/workflow_spec.rb",         
    "workflow.gemspec",
    "workflow.rb"
  ]
  gem.homepage = %q{http://www.geekq.net/workflow/}
  gem.require_paths = ["lib"]
  gem.rubyforge_project = %q{workflow}
  gem.rubygems_version = %q{1.3.6}
  gem.summary = %q{A replacement for acts_as_state_machine.}

  if gem.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    gem.specification_version = 3
  end
  gem.add_development_dependency 'rdoc',    [">= 3.12"]
  gem.add_development_dependency 'bundler', [">= 1.0.0"]
  gem.add_development_dependency 'activerecord'
  gem.add_development_dependency 'sqlite3'
  gem.add_development_dependency 'mocha'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'ruby-graphviz', ['>= 1.0']
end

