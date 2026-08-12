# frozen_string_literal: true

# Configure Active Record Encryption from environment variables when
# Rails credentials are unavailable (e.g. CI / local test environments).
primary_key         = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence || (Rails.env.test? ? "test_primary_key_for_encryption_32b" : nil)
deterministic_key   = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence || (Rails.env.test? ? "test_deterministic_key_for_enc" : nil)
key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence || (Rails.env.test? ? "test_key_derivation_salt_value" : nil)

if primary_key.present?
  Rails.application.config.active_record.encryption.primary_key         = primary_key
  Rails.application.config.active_record.encryption.deterministic_key   = deterministic_key
  Rails.application.config.active_record.encryption.key_derivation_salt = key_derivation_salt
end
