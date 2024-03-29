# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "workpile/version"

Gem::Specification.new do |s|
  s.name        = "workpile"
  s.version     = Workpile::VERSION
  s.authors     = ["drvo"]
  s.email       = ["drvo.gm@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{pipe manage subprocess}
  s.description = %q{create subprocess by pipe. manage that.}

  s.rubyforge_project = "workpile"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  
  s.add_dependency "fssm"
end
