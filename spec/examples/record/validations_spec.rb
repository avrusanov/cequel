require_relative 'spec_helper'

describe Cequel::Record::Validations do
  model :Post do
    key :permalink, :text
    column :title, :text
    column :body, :text

    validates :title, presence: true
    before_validation { |post| post.called_validate_callback = true }

    attr_accessor :called_validate_callback
  end

  let(:invalid_post) do
    Post.new do |post|
      post.permalink = 'invalid'
      post.body = 'This is an invalid post.'
    end
  end
  let(:valid_post) do
    Post.new do |post|
      post.permalink = 'valid'
      post.title = 'Valid Post'
    end
  end
  let(:unloaded_post) { Post['unloaded'] }

  describe '#valid?' do
    it 'is false if model is not valid' do
      expect(invalid_post).not_to be_valid
    end

    it 'is true if model is valid' do
      expect(valid_post).to be_valid
    end
  end

  describe '#invalid?' do
    it 'is true if model is not valid' do
      expect(invalid_post).to be_invalid
    end

    it 'is false if model is valid' do
      expect(valid_post).not_to be_invalid
    end
  end

  describe '#save' do
    it 'returns false and not persist model if invalid' do
      expect(invalid_post.save).to be(false)
    end

    it 'returns true and persist model if valid' do
      expect(valid_post.save).to be(true)
      expect(Post.find('valid').title).to eq('Valid Post')
    end

    it 'bypasses validations if :validate => false is passed' do
      expect(invalid_post.save(validate: false)).to be(true)
      expect(Post.find('invalid').body).to eq('This is an invalid post.')
    end
  end

  describe '#save!' do
    it 'raises error and not persist model if invalid' do
      expect { invalid_post.save! }
        .to raise_error(Cequel::Record::RecordInvalid)
    end

    it 'persists model and return self if valid' do
      expect { valid_post.save! }.not_to raise_error
      expect(Post.find(valid_post.permalink).title).to eq('Valid Post')
    end
  end

  describe '#update_attributes!' do
    it 'raises error and not update data in the database' do
      expect { invalid_post.update_attributes!(body: 'My Post') }
        .to raise_error(Cequel::Record::RecordInvalid)
    end

    it 'returns successfully and update data in the database if valid' do
      invalid_post.update_attributes!(title: 'My Post')
      expect(Post.find(invalid_post.permalink).title).to eq('My Post')
    end
  end

  describe '::create!' do
    it 'raises RecordInvalid and not persist model if invalid' do
      expect do
        Post.create!(permalink: 'cequel', body: 'Cequel')
      end.to raise_error(Cequel::Record::RecordInvalid)
    end

    it 'persists record to database if valid' do
      Post.create!(permalink: 'cequel', title: 'Cequel')
      expect(Post.find('cequel').title).to eq('Cequel')
    end
  end

  describe 'callbacks' do
    it 'calls validation callbacks' do
      post = Post.new(title: 'cequel')
      post.valid?
      expect(post.called_validate_callback).to be(true)
    end
  end
end
