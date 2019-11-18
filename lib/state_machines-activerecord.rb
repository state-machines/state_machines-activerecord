require 'active_support'
require 'state_machines/integrations/active_record'

ActiveSupport.on_load(:i18n) do
  I18n.load_path << File.expand_path('state_machines/integrations/active_record/locale.rb', __dir__)
end
