require_relative 'spec_helper'

describe 'naming' do
  model :Blog do
    key :subdomain, :text
    column :name, :text
  end

  it 'implements model_name' do
    expect(Blog.model_name).to eq('Blog')
  end

  it 'implements model_name interpolations' do
    expect(Blog.model_name.i18n_key).to eq(:blog)
  end
end
