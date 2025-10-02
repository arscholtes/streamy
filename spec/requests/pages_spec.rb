require 'rails_helper'

RSpec.describe "Pages", type: :request do
  describe "GET /landing" do
    it "returns http success" do
      get "/pages/landing"
      expect(response).to have_http_status(:success)
    end
  end

end
