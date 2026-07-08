require_relative 'spec_helper'

describe 'serialization' do
  model :Post do
    key :blog_subdomain, :text
    key :id, :uuid, auto: true
    column :title, :text
    column :body, :text
  end

  uuid :id

  let(:attributes) do
    {
      blog_subdomain: 'big-data',
      id: id,
      title: 'Cequel'
    }
  end

  let(:post) { Post.new(attributes) }

  before do
    Post.include_root_in_json = false
  end

  it 'provides JSON serialization' do
    json = post.as_json.symbolize_keys
    expect(json).to eq(attributes.merge(id: attributes[:id].to_s, body: nil))
  end

  it 'is able to serialize restricting to some attributes' do
    json = post.as_json(only: [:id]).symbolize_keys
    expect(json).to eq(id: attributes[:id].to_s)
  end
end
