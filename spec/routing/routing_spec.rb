require 'rails_helper'

describe 'Routing', type: :routing do
  describe 'Default route' do
    it "should route '/', :to => 'authentication#index'" do
      expect(get: '/').to route_to('authentication#index')
    end
  end
end
