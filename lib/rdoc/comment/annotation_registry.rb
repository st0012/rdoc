# frozen_string_literal: true

##
# Registry mapping annotation tag names (e.g. "override") to handler classes.
# Handlers must define constant +NAME+ (the tag) and +APPLIES_TO+ (an Array of
# CodeObject classes the annotation can attach to) and a class method
# +apply(param, code_object)+ that mutates the +code_object+.

module RDoc::Comment::AnnotationRegistry
  @handlers = {}

  def self.register(handler)
    @handlers[handler::NAME] = handler
  end

  def self.unregister(name)
    @handlers.delete(name)
  end

  def self.lookup(tag)
    @handlers[tag]
  end

  def self.handlers # :nodoc:
    @handlers.dup
  end
end

require_relative 'annotation/override'
require_relative 'annotation/abstract'
