# frozen_string_literal: true

require_relative '../../helper'

class TestRDocCommentAnnotationAbstract < RDoc::TestCase
  def test_name_constant
    assert_equal 'abstract', RDoc::Comment::Annotation::Abstract::NAME
  end

  def test_applies_to_methods_and_classes
    assert_equal [RDoc::AnyMethod, RDoc::ClassModule],
                 RDoc::Comment::Annotation::Abstract::APPLIES_TO
  end

  def test_apply_to_method_sets_abstract
    m = RDoc::AnyMethod.new nil, 'render'
    RDoc::Comment::Annotation::Abstract.apply nil, m
    assert_equal true, m.abstract
  end

  def test_apply_to_class_sets_abstract
    cm = RDoc::NormalClass.new 'Component'
    RDoc::Comment::Annotation::Abstract.apply nil, cm
    assert_equal true, cm.abstract
  end
end
