# frozen_string_literal: true

##
# Handler for +@abstract+ annotations on methods or classes/modules.
#
# Sets <tt>code_object.abstract = true</tt>.

class RDoc::Comment::Annotation::Abstract
  NAME       = 'abstract'
  APPLIES_TO = [RDoc::AnyMethod, RDoc::ClassModule]

  def self.apply(_param, code_object)
    code_object.abstract = true
  end
end

RDoc::Comment::AnnotationRegistry.register RDoc::Comment::Annotation::Abstract
