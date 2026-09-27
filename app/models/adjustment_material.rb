class AdjustmentMaterial < ApplicationRecord
  belongs_to :material
  belongs_to :staff
  has_one :material_movement, as: :source

  validates :note, presence: true

  before_update :prevent_update

  private

  def prevent_update
    raise ActiveRecord::ReadOnlyRecord if persisted? && changed?
  end
end
