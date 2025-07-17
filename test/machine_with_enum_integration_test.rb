# frozen_string_literal: true

require_relative 'test_helper'

class MachineWithEnumIntegrationTest < BaseTestCase
  def setup
    @original_stderr = $stderr
    $stderr = StringIO.new

    @model = new_model do
      connection.add_column table_name, :status, :integer, default: 0
      enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }
    end
  end

  def teardown
    $stderr = @original_stderr
  end

  test 'should auto detect enum integration' do
    @machine = StateMachines::Machine.new(@model, :status)
    @machine.state :pending, :processing, :completed, :failed

    # Test enum integration detection
    assert @machine.respond_to?(:enum_integrated?), 'Machine should respond to enum_integrated?'
    assert @machine.enum_integrated?
    assert_equal({ 'pending' => 0, 'processing' => 1, 'completed' => 2, 'failed' => 3 }, @machine.enum_mapping)

    # Test that states are properly defined using shared assertions
    assert_sm_states_list(@machine, %i[pending processing completed failed])
  end

  test 'should not auto detect when no enum exists' do
    @model_without_enum = new_model
    machine = @model_without_enum.state_machine(:status) do
      state :pending, :processing, :completed, :failed
    end

    assert_not machine.enum_integrated?
    # Test that states are still properly defined even without enum integration
    assert_sm_states_list(machine, %i[pending processing completed failed])
  end

  test 'should detect existing enum methods' do
    machine = @model.state_machine(:status) do
      state :pending, :processing, :completed, :failed
    end

    original_methods = machine.original_enum_methods
    assert_includes original_methods, 'pending?'
    assert_includes original_methods, 'processing?'
    assert_includes original_methods, 'completed?'
    assert_includes original_methods, 'failed?'
  end

  test 'should generate prefixed method names for enum integration' do
    machine = @model.state_machine(:status) do
      state :pending, :processing, :completed, :failed
    end

    assert_equal 'status_pending?', machine.send(:generate_state_method_name, 'pending', :predicate)
    assert_equal 'status_processing!', machine.send(:generate_state_method_name, 'processing', :bang)
    assert_equal 'status_completed', machine.send(:generate_state_method_name, 'completed', :scope)
  end

  test 'should store default enum integration metadata' do
    machine = @model.state_machine(:status) do
      state :pending, :processing, :completed, :failed
    end

    config = machine.enum_integration
    assert_equal true, config[:prefix]
    assert_equal false, config[:suffix]
    assert_equal true, config[:scopes]
  end

  test 'should generate prefixed predicate methods' do
    @model.state_machine(:status) do
      state :pending, :processing, :completed, :failed
    end

    record = @model.create(status: :pending)

    # Test using shared state machine assertions
    assert_sm_state(record, :pending, machine_name: :status)

    # Original enum methods should still work
    assert record.pending?
    assert_not record.processing?

    # Prefixed state machine methods should be generated
    assert record.respond_to?(:status_pending?)
    assert record.respond_to?(:status_processing?)
    assert record.respond_to?(:status_completed?)
    assert record.respond_to?(:status_failed?)

    # Prefixed methods should work correctly
    assert record.status_pending?
    assert_not record.status_processing?
    assert_not record.status_completed?
    assert_not record.status_failed?
  end

  test 'should generate prefixed bang methods' do
    @model.state_machine(:status) do
      state :pending, :processing, :completed, :failed

      event :process do
        transition pending: :processing
      end

      event :complete do
        transition processing: :completed
      end

      event :fail do
        transition %i[pending processing] => :failed
      end
    end

    record = @model.create(status: :pending)

    # Prefixed bang methods should be available
    assert record.respond_to?(:status_processing!)
    assert record.respond_to?(:status_completed!)
    assert record.respond_to?(:status_failed!)

    # Bang methods should exist but raise an exception (conflict resolution, not full functionality)
    assert_raises(RuntimeError) do
      record.status_failed!
    end
  end

  test 'should generate prefixed scope methods' do
    @model.state_machine(:status) do
      state :pending, :processing, :completed, :failed
    end

    pending_record = @model.create(status: :pending)
    processing_record = @model.create(status: :processing)
    completed_record = @model.create(status: :completed)

    # Test record states using shared assertions
    assert_sm_state(pending_record, :pending, machine_name: :status)
    assert_sm_state(processing_record, :processing, machine_name: :status)
    assert_sm_state(completed_record, :completed, machine_name: :status)

    # Test state persistence using shared assertions
    assert_sm_state_persisted(pending_record, 'pending', :status)
    assert_sm_state_persisted(processing_record, 'processing', :status)
    assert_sm_state_persisted(completed_record, 'completed', :status)

    # Prefixed scope methods should be available
    assert @model.respond_to?(:status_pending)
    assert @model.respond_to?(:status_processing)
    assert @model.respond_to?(:status_completed)
    assert @model.respond_to?(:status_failed)

    # Negative scope methods should be available
    assert @model.respond_to?(:not_status_pending)
    assert @model.respond_to?(:not_status_processing)

    # Scopes should work correctly
    assert_equal [pending_record], @model.status_pending.to_a
    assert_equal [processing_record], @model.status_processing.to_a
    assert_equal [completed_record], @model.status_completed.to_a
    assert_equal [], @model.status_failed.to_a

    # Negative scopes should work
    assert_equal [processing_record, completed_record], @model.not_status_pending.order(:id).to_a
  end

  test 'should track generated methods for introspection' do
    machine = @model.state_machine(:status) do
      state :pending, :processing, :completed, :failed
    end

    generated_methods = machine.state_machine_methods

    # Should track all generated prefixed methods
    assert_includes generated_methods, 'status_pending?'
    assert_includes generated_methods, 'status_processing?'
    assert_includes generated_methods, 'status_completed?'
    assert_includes generated_methods, 'status_failed?'

    assert_includes generated_methods, 'status_pending!'
    assert_includes generated_methods, 'status_processing!'
    assert_includes generated_methods, 'status_completed!'
    assert_includes generated_methods, 'status_failed!'

    assert_includes generated_methods, 'status_pending'
    assert_includes generated_methods, 'status_processing'
    assert_includes generated_methods, 'status_completed'
    assert_includes generated_methods, 'status_failed'
  end
end
