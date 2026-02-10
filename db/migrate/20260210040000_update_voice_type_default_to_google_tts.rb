class UpdateVoiceTypeDefaultToGoogleTts < ActiveRecord::Migration[7.0]
  def up
    change_column_default :check_in_displays, :voice_type, 'ms-MY-Wavenet-A'

    # Migrate existing records with old Web Speech API voice format
    execute <<-SQL.squish
      UPDATE check_in_displays
      SET voice_type = 'ms-MY-Wavenet-A'
      WHERE voice_type IS NULL
         OR voice_type NOT LIKE '%Wavenet%'
    SQL
  end

  def down
    change_column_default :check_in_displays, :voice_type, 'en-US-female'
  end
end
