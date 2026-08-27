# frozen_string_literal: true

module UI
  class Button < Component
    # Render the button.
    #
    # @override
    def render(context)
      "<button>#{context}</button>"
    end
  end
end
