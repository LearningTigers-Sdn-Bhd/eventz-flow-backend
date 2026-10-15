# The original reply a binding operation gave, keyed the same way as a desk
# scan: a replayed operation must not revoke the binding that replaced it.
module Rfid
  class BindingOperation < ApplicationRecord
    self.table_name = 'rfid_binding_operations'

    belongs_to :event

    validates :operation_id, presence: true
    validates :request_digest, presence: true
  end
end
