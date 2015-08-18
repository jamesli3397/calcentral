require 'spec_helper'

describe CampusSolutions::AddressLabel do

  shared_examples 'a proxy that gets data' do
    subject { proxy.get }
    it_should_behave_like 'a simple proxy that returns errors'

    it 'returns data with the expected structure' do
      expect(subject[:feed][:labels]).to be
      expect(subject[:feed][:labels][0][:label]).to be
      expect(subject[:feed][:labels][0][:field]).to be
    end
  end

  context 'mock proxy' do
    let(:proxy) { CampusSolutions::AddressLabel.new(fake: true, country: 'USA') }
    it_should_behave_like 'a proxy that gets data'
  end

  context 'real proxy', testext: true do
    let(:proxy) { CampusSolutions::AddressLabel.new(fake: false, country: 'USA') }
    it_should_behave_like 'a proxy that gets data'
  end

end
