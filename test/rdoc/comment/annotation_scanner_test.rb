# frozen_string_literal: true

require_relative '../helper'

class TestRDocCommentAnnotationScanner < RDoc::TestCase
  def setup
    super
    @method = RDoc::AnyMethod.new 'render'
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

  def test_strips_annotation_lines_with_a_ruby_comment_prefix
    out = RDoc::Comment::AnnotationScanner.scan "# @override\n", @method

    assert_equal '', out
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

  def test_leaves_override_on_classes_in_place
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

  def test_leaves_annotation_with_trailing_text_in_place
    text = "@abstract implement render\n"
    out = RDoc::Comment::AnnotationScanner.scan text, @method

    assert_equal text, out
    assert_equal false, @method.abstract
  end
end
