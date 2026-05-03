# frozen_string_literal: true

require_relative '../../helper'

class TestRDocCommentAnnotationOverride < RDoc::TestCase
  def test_name_constant
    assert_equal 'override', RDoc::Comment::Annotation::Override::NAME
  end

  def test_applies_to_any_method_only
    assert_equal [RDoc::AnyMethod],
                 RDoc::Comment::Annotation::Override::APPLIES_TO
  end

  def test_apply_sets_override_true
    m = RDoc::AnyMethod.new nil, 'render'
    RDoc::Comment::Annotation::Override.apply nil, m
    assert_equal true,  m.override
    assert_nil          m.override_target
  end
end
