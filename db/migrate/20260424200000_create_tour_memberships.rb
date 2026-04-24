class CreateTourMemberships < ActiveRecord::Migration[8.0]
  def up
    create_table :tour_memberships, id: :uuid do |t|
      t.references :tour,     null: false, type: :uuid, foreign_key: { to_table: :activities }
      t.references :activity, null: false, type: :uuid, foreign_key: { to_table: :activities }
      t.timestamps
    end

    add_index :tour_memberships, [:tour_id, :activity_id], unique: true

    # Migrate existing tour_id associations into the join table
    execute <<~SQL
      INSERT INTO tour_memberships (id, tour_id, activity_id, created_at, updated_at)
      SELECT gen_random_uuid(), tour_id, id, NOW(), NOW()
      FROM activities
      WHERE tour_id IS NOT NULL AND (type IS NULL OR type = '')
    SQL

    remove_column :activities, :tour_id, :uuid
  end

  def down
    add_column :activities, :tour_id, :uuid
    add_index  :activities, :tour_id

    execute <<~SQL
      UPDATE activities a
      SET tour_id = tm.tour_id
      FROM tour_memberships tm
      WHERE tm.activity_id = a.id
    SQL

    drop_table :tour_memberships
  end
end
