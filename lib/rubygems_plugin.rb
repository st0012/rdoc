# frozen_string_literal: true

# If this file is exist, RDoc generates and removes documents by rubygems plugins.
#
# In follwing cases,
# RubyGems directly exectute RDoc::RubygemsHook.generation_hook and RDoc::RubygemsHook#remove to generate and remove documents.
#
# - RDoc is used as a default gem.
# - RDoc is a old version that doesn't have rubygems_plugin.rb.

# rdoc/rubygems_hook pulls in the full RDoc library, so defer the require
# until a hook actually fires to keep `gem` startup fast.
Gem.done_installing do |installer, specs|
  require_relative 'rdoc/rubygems_hook'
  RDoc::RubyGemsHook.generate(installer, specs)
end

Gem.pre_uninstall do |uninstaller|
  require_relative 'rdoc/rubygems_hook'
  RDoc::RubyGemsHook.remove(uninstaller)
end
