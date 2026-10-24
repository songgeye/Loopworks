class Staff < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :rememberable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist
  has_many :inbounds
  has_many :outbounds
  has_many :adjustment_materials
  has_many :material_movements

  validates :username, presence: true, uniqueness: true
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: %w[admin staff]}

  def admin?
    role == "admin"
  end
end
