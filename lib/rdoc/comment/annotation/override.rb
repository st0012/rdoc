# frozen_string_literal: true

##
# Handler for +@override+ annotations on methods.
#
# Sets <tt>code_object.override = true</tt>. The override target (full name of
# the overridden ancestor method) is resolved later by
# RDoc::Store#resolve_annotations once all classes/modules are known.

class RDoc::Comment::Annotation::Override
  NAME       = 'override'
  APPLIES_TO = [RDoc::AnyMethod]

  def self.apply(_param, code_object)
    code_object.override = true
  end
end

RDoc::Comment::AnnotationRegistry.register RDoc::Comment::Annotation::Override
