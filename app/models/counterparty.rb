class Counterparty < ApplicationRecord
  has_many :inbounds
  has_many :outbounds

  enum :party_type, { corporate: 0, individual: 1 }

  enum :id_type, {
    drivers_license: 0,
    my_number_card: 1,
    health_insurance: 2,
    passport: 3,
    residence_card: 4,
    other: 5
  }
end
