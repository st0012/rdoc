# frozen_string_literal: true

require_relative '../helper'

class TestRDocCommentAnnotationRegistry < RDoc::TestCase
  def test_register_and_lookup
    klass = Class.new
    klass.const_set(:NAME, 'fake')
    klass.const_set(:APPLIES_TO, [Object])

    RDoc::Comment::AnnotationRegistry.register klass
    assert_equal klass, RDoc::Comment::AnnotationRegistry.lookup('fake')
  ensure
    RDoc::Comment::AnnotationRegistry.unregister 'fake'
  end

  def test_lookup_unknown_returns_nil
    assert_nil RDoc::Comment::AnnotationRegistry.lookup('nonexistent')
  end
end
