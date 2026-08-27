# frozen_string_literal: true

##
# Scans comment text for RDoc's built-in <tt>@abstract</tt> and
# <tt>@override</tt> annotations. Applies supported annotations to
# +code_object+ and returns the text with those annotation lines removed.

class RDoc::Comment::AnnotationScanner
  ANNOTATION_LINE = /\A(?:# ?)?@(abstract|override)[ \t]*\z/

  def self.scan(text, code_object)
    return text if text.nil? || text.empty?
    return text unless text.include?('@')

    text.each_line.reject do |line|
      next false unless (m = line.chomp.match(ANNOTATION_LINE))

      case m[1]
      when 'abstract'
        next false unless code_object.is_a?(RDoc::AnyMethod) ||
                          code_object.is_a?(RDoc::ClassModule)
        code_object.abstract = true
      when 'override'
        next false unless code_object.is_a?(RDoc::AnyMethod)
        code_object.override = true
      end

      true
    end.join
  end
end
