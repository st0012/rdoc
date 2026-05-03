# frozen_string_literal: true

module UI
  # Standalone class — has @override on a method whose name does not exist
  # in any ancestor. Used to test the unresolved-warning path.
  class Orphan
    # @override
    def nonexistent
    end
  end
end
