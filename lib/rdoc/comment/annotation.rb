# frozen_string_literal: true

module RDoc::Comment::Annotation
  autoload :Override, "#{__dir__}/annotation/override"
  autoload :Abstract, "#{__dir__}/annotation/abstract"
end
