{ en: {
    activerecord: {
        errors: {
            messages: {
                invalid: StateMachines::Machine.default_messages[:invalid],
                invalid_event: StateMachines::Machine.default_messages[:invalid_event] % ['%{state}'],
                invalid_transition: StateMachines::Machine.default_messages[:invalid_transition] % ['%{event}']
            }
        }
    }
} }

