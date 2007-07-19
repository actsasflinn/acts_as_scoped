ActiveRecord::Schema.define(:version => 1) do

  create_table :things, :force => true do |t|
    t.column :name, :string
    t.column :user_id, :integer
  end

  create_table :items, :force => true do |t|
    t.column :name, :string
    t.column :user_id, :integer
  end

  create_table :features, :force => true do |t|
    t.column :name, :string
    t.column :user_id, :integer
  end

  create_table :users, :force => true do |t|
    t.column :name, :string
    t.column :description, :text
  end
end