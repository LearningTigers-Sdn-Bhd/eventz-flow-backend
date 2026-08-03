class ShortenExhibitorKitPublicIds < ActiveRecord::Migration[8.0]
  def up
    change_column_default :exhibitor_kits, :public_id, nil
    change_column :exhibitor_kits, :public_id, :string, using: 'public_id::text'
    change_column_default :exhibitor_kits, :public_id, -> { 'gen_random_uuid()::text' }
  end

  def down
    change_column :exhibitor_kits, :public_id, :uuid, using: 'public_id::uuid', default: -> { 'gen_random_uuid()' }
  end
end
