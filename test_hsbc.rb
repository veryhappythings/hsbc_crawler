require 'hsbc'
require "test/unit"

class TestHsbc < Test::Unit::TestCase
  def test_include_any
    str = 'hello there!'
    assert_equal(include_any?(str, ['he', 'jam', 'toast']), true)
    assert_equal(include_any?(str, ['shoes', 'there', 'hell']), true)
    assert_equal(include_any?(str, ['japan', 'france', 'doberman']), false)
  end
end

