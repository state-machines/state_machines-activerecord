ActiveRecord::Base.connection.create_table(:posts, :force => true) do |t|
  t.string :title
  t.string :content
  t.string :state
end

class Post < ActiveRecord::Base
  state_machine initial: :draft do

  end
end