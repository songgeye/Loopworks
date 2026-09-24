class Counterparty < ApplicationRecord
  has_many :inbounds
  has_many :outbounds
end
