require File.expand_path('spec_helper', __dir__)

describe Cequel::Record::Dirty do
  model :Post do
    key :permalink, :text
    column :title, :text
    set :categories, :text
    column :created_at, :timestamp
  end

  context 'loaded model' do
    let(:created_at_float) { 1_455_754_622.8502421 }
    let(:post) do
      Post.create!(
        permalink: 'cequel',
        title: 'Cequel',
        categories: Set['Libraries'],
        created_at: created_at_float
      )
    end

    it 'does not have changed attributes by default' do
      expect(post.changed_attributes).to be_empty
    end

    it 'has changed attributes if attributes change' do
      post.title = 'Cequel ORM'
      expect(post.changed_attributes)
        .to eq({title: 'Cequel'}.with_indifferent_access)
    end

    it 'does not have changed attributes if attribute set to the same thing' do
      post.title = 'Cequel'
      expect(post.changed_attributes).to be_empty
    end

    it 'supports *_changed? method' do
      post.title = 'Cequel ORM'
      expect(post.title_changed?).to be(true)
    end

    it 'does not have changed attributes after save' do
      post.title = 'Cequel ORM'
      post.save
      expect(post.changed_attributes).to be_empty
    end

    it 'has previous changes after save' do
      post.title = 'Cequel ORM'
      post.save
      expect(post.previous_changes)
        .to eq({ title: ['Cequel', 'Cequel ORM'] }.with_indifferent_access)
    end

    it 'detects changes to collections' do
      post.categories << 'Gems'
      expect(post.changes).to eq(
        {categories: [Set['Libraries'], Set['Libraries', 'Gems']]}
        .with_indifferent_access
      )
    end

    it 'checks dirty state against correctly cast timestamp values' do
      post.created_at = created_at_float
      expect(post.changed_attributes).to be_empty
    end
  end

end
