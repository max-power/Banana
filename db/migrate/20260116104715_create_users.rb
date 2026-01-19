class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :email, null: false
      t.datetime :verified_at

      t.timestamps
      t.index ["email"], name: "index_users_on_email", unique: true
    end
  end
end
