class AddPublicProfileAndShareTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :public_profile, :boolean, null: false, default: false

    add_column :activities, :share_token, :string
    add_index :activities, :share_token, unique: true

    reversible do |dir|
      dir.up do
        execute "UPDATE activities SET share_token = md5(random()::text || id::text)"
        change_column_null :activities, :share_token, false
      end
    end
  end
end
