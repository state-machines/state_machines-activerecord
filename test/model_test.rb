require_relative 'test_helper'
require_relative 'files/models/post'

class ModelTest < ActiveSupport::TestCase
  def test_should_have_draft_state_in_defaut_machine
    assert_equal 'draft', Post.new.state
  end

  def test_should_have_the_correct_integration
    assert_equal StateMachines::Integrations::ActiveRecord, StateMachines::Integrations.match(Post)
  end
end
