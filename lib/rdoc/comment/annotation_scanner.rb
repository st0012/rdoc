# frozen_string_literal: true

##
# Scans comment text line-by-line for <tt>@tag [param]</tt> annotations,
# applies the corresponding handler from RDoc::Comment::AnnotationRegistry to
# +code_object+, and returns the text with the annotation lines stripped.
#
# Lines whose tag is not registered, or whose handler does not apply to the
# given +code_object+'s class, are left unchanged.

class RDoc::Comment::AnnotationScanner
  ANNOTATION_LINE = /\A\s*@(\w+)(?:[ \t]+(\S.*?))?[ \t]*\z/

  def self.scan(text, code_object)
    return text if text.nil? || text.empty?

    text.each_line.reject do |line|
      next false unless (m = line.chomp.match(ANNOTATION_LINE))
      handler = RDoc::Comment::AnnotationRegistry.lookup(m[1])
      next false unless handler
      next false unless handler::APPLIES_TO.any? { |k| code_object.is_a?(k) }
      handler.apply m[2], code_object
      true
    end.join
  end
end
