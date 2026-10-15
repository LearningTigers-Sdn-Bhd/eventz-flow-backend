# The original reply a desk scan gave, saved by (event_id, operation_id) so a
# replayed operation answers exactly what it answered the first time. The
# unique index is the arbitration; this model is only the reader/writer.
module Rfid
  class DeskOperation < ApplicationRecord
    self.table_name = 'rfid_desk_operations'

    belongs_to :event

    validates :operation_id, presence: true
    validates :request_digest, presence: true
  end
end
