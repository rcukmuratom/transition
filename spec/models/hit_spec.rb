require 'spec_helper'

describe Hit do
  describe 'relationships' do
    it { should belong_to(:host) }
  end

  describe 'validations' do
    it { should validate_presence_of(:host) }
    it { should validate_presence_of(:path) }
    it { should validate_presence_of(:path_hash) }
    it { should validate_presence_of(:count) }
    it { should validate_numericality_of(:count).is_greater_than_or_equal_to(0) }
  end

  describe 'attributes set before validation' do
    subject { create :hit, hit_on: DateTime.new(2014, 12, 31, 23, 59, 59) }

    its(:hit_on)    { should eql(DateTime.new(2014, 12, 31, 0, 0, 0)) }
    its(:path_hash) { should eql('88bf0e0efdd1f1e0a7ea7958bcc9083e4a166c8e') }
  end
end