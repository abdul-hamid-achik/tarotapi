require 'rails_helper'

RSpec.describe IdentityProvider, type: :model do
  describe 'associations' do
    it { should have_many(:users) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    
    it 'validates uniqueness of name' do
      # Create a record first
      IdentityProvider.create!(name: 'test-provider', description: 'test')
      
      # Then test uniqueness
      provider = IdentityProvider.new(name: 'test-provider')
      expect(provider).not_to be_valid
      expect(provider.errors[:name]).to include('has already been taken')
    end
  end

  describe 'constants' do
    it 'defines ANONYMOUS constant' do
      expect(IdentityProvider::ANONYMOUS).to eq('anonymous')
    end
    
    it 'defines REGISTERED constant' do
      expect(IdentityProvider::REGISTERED).to eq('registered')
    end
    
    it 'defines AGENT constant' do
      expect(IdentityProvider::AGENT).to eq('agent')
    end
  end

  describe '.anonymous' do
    it 'finds or creates an anonymous provider' do
      provider = IdentityProvider.anonymous
      
      expect(provider).to be_persisted
      expect(provider.name).to eq(IdentityProvider::ANONYMOUS)
      expect(provider.description).to include('anonymous')
    end
    
    it 'returns the same provider on subsequent calls' do
      first_call = IdentityProvider.anonymous
      second_call = IdentityProvider.anonymous
      
      expect(second_call).to eq(first_call)
    end
  end
  
  describe '.registered' do
    it 'finds or creates a registered provider' do
      provider = IdentityProvider.registered
      
      expect(provider).to be_persisted
      expect(provider.name).to eq(IdentityProvider::REGISTERED)
      expect(provider.description).to include('registered')
    end
    
    it 'returns the same provider on subsequent calls' do
      first_call = IdentityProvider.registered
      second_call = IdentityProvider.registered
      
      expect(second_call).to eq(first_call)
    end
  end
  
  describe '.agent' do
    it 'finds or creates an agent provider' do
      provider = IdentityProvider.agent
      
      expect(provider).to be_persisted
      expect(provider.name).to eq(IdentityProvider::AGENT)
      expect(provider.description).to include('agent')
    end
    
    it 'returns the same provider on subsequent calls' do
      first_call = IdentityProvider.agent
      second_call = IdentityProvider.agent
      
      expect(second_call).to eq(first_call)
    end
  end
end 