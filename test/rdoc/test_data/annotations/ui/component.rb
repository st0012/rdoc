# frozen_string_literal: true

module UI
  # Base class for renderable UI components.
  #
  # @abstract
  class Component
    # Render the component to HTML.
    #
    # @abstract
    def render(context)
      raise NotImplementedError
    end
  end
end
