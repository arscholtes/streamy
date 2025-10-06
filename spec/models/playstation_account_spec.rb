require 'rails_helper'

RSpec.describe PlaystationAccount, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end
end
