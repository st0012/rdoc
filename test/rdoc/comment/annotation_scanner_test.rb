# frozen_string_literal: true

require_relative '../helper'

class TestRDocCommentAnnotationScanner < RDoc::TestCase
  def setup
    super
    @method = RDoc::AnyMethod.new nil, 'render'
    @klass  = RDoc::NormalClass.new 'Component'
  end

  def test_strips_known_annotation_lines
    text = <<~TEXT
      Returns the rendered HTML.

      @override
    TEXT
    out = RDoc::Comment::AnnotationScanner.scan text, @method
    assert_equal "Returns the rendered HTML.\n\n", out
    assert_equal true, @method.override
  end

  def test_leaves_unknown_at_tags_in_place
    text = <<~TEXT
      Renders the component.

      @example Foo.new.render
    TEXT
    out = RDoc::Comment::AnnotationScanner.scan text, @method
    assert_includes out, '@example Foo.new.render'
  end

  def test_skips_handler_when_owner_kind_does_not_apply
    # @override applies only to AnyMethod; passing a ClassModule should not
    # invoke the handler, and the line should remain in the text.
    text = "@override\n"
    out = RDoc::Comment::AnnotationScanner.scan text, @klass
    assert_equal "@override\n", out
  end

  def test_abstract_works_on_both_methods_and_classes
    text = "@abstract\n"
    RDoc::Comment::AnnotationScanner.scan text, @method
    assert_equal true, @method.abstract
    RDoc::Comment::AnnotationScanner.scan text, @klass
    assert_equal true, @klass.abstract
  end

  def test_preserves_indentation_of_kept_lines
    text = "  description with leading spaces\n@override\n"
    out = RDoc::Comment::AnnotationScanner.scan text, @method
    assert_equal "  description with leading spaces\n", out
  end
end
