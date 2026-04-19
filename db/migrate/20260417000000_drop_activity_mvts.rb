class DropActivityMvts < ActiveRecord::Migration[8.1]
    def up
        drop_view :activity_mvts, materialized: true
    end

    def down
        raise ActiveRecord::IrreversibleMigration
    end
end
