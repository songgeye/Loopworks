class Counterparty < ApplicationRecord
  has_many :inbounds
  has_many :outbounds

  validates :name, presence: true

  enum :party_type, {
    corporate: 0,
    individual: 1
  }, validate: true

  enum :id_type, {
    drivers_license: 0,
    my_number_card: 1,
    health_insurance: 2,
    passport: 3,
    residence_card: 4,
    other: 5
  }, validate: { allow_nil: true }
end
