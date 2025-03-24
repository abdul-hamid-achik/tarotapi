# This initializer configures ActiveRecord encryption with keys from environment variables.
# In a production environment, these keys should be stored securely.

Rails.application.config.to_prepare do
  ActiveRecord::Encryption.configure(
    primary_key: ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"],
    deterministic_key: ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"],
    key_derivation_salt: ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
  )
end
