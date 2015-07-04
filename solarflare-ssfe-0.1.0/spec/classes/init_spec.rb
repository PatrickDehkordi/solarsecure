require 'spec_helper'
describe 'ssfe' do

  context 'with defaults for all parameters' do
    it { should contain_class('ssfe') }
  end
end
