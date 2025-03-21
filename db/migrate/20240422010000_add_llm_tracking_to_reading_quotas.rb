class AddLlmTrackingToReadingQuotas < ActiveRecord::Migration[7.1]
  def change
    add_column :reading_quotas, :llm_calls_this_month, :integer, default: 0, null: false
    add_column :reading_quotas, :llm_calls_limit, :integer, default: 1000, null: false
    add_column :reading_quotas, :last_llm_call_at, :datetime
  end
end
