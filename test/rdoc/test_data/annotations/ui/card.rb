# frozen_string_literal: true

module UI
  class Card < Component
    # Render the card.
    #
    # @override
    def render(context)
      "<div class='card'>#{context}</div>"
    end
  end
end
