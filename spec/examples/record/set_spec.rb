require File.expand_path('spec_helper', __dir__)

describe Cequel::Record::Set do
  model :Post do
    key :permalink, :text
    column :title, :text
    set :tags, :text
  end

  subject { scope.first }

  let(:scope) { cequel[Post.table_name].where(permalink: 'cequel') }
  let! :post do
    Post.new do |post|
      post.permalink = 'cequel'
      post.tags = Set['one', 'two']
    end.tap(&:save)
  end
  let! :unloaded_post do
    Post['cequel']
  end

  context 'new record' do
    it 'saves set as-is' do
      expect(subject[:tags]).to eq(Set['one', 'two'])
    end
  end

  context 'updating' do
    it 'overwrites value' do
      post.tags = Set['three', 'four']
      post.save!
      expect(subject[:tags]).to eq(Set['three', 'four'])
    end

    it 'casts collection before overwriting' do
      post.tags = %w[three four]
      post.save!
      expect(subject[:tags]).to eq(Set['three', 'four'])
    end
  end

  describe 'atomic modification' do
    before { scope.set_add(:tags, 'three') }

    describe '#add' do
      it 'adds atomically' do
        post.tags.add('four')
        post.save
        expect(subject[:tags]).to eq(Set['one', 'two', 'three', 'four'])
        expect(post.tags).to eq(Set['one', 'two', 'four'])
      end

      it 'casts before adding' do
        post.tags.add(4)
        expect(post.tags).to eq(Set['one', 'two', '4'])
      end

      it 'adds without reading' do
        expect_statement_count 1 do
          unloaded_post.tags.add('four')
          unloaded_post.save
        end
        expect(subject[:tags]).to eq(Set['one', 'two', 'three', 'four'])
      end

      it 'applies add post-hoc' do
        unloaded_post.tags.add('four')
        expect(unloaded_post.tags).to eq(Set['one', 'two', 'three', 'four'])
      end
    end

    describe '#clear' do
      it 'clears atomically' do
        post.tags.clear
        post.save
        expect(subject[:tags]).to be_blank
        expect(post.tags).to eq(Set[])
      end

      it 'clears without reading' do
        expect_statement_count 1 do
          unloaded_post.tags.clear
          unloaded_post.save
        end
        expect(subject[:tags]).to be_blank
      end

      it 'applies clear post-hoc' do
        unloaded_post.tags.clear
        expect(unloaded_post.tags).to eq(Set[])
      end
    end

    describe '#delete' do
      it 'deletes atomically' do
        post.tags.delete('two')
        post.save
        expect(subject[:tags]).to eq(Set['one', 'three'])
        expect(post.tags).to eq(Set['one'])
      end

      it 'casts before deleting' do
        post.tags.delete(:two)
        expect(post.tags).to eq(Set['one'])
      end

      it 'deletes without reading' do
        expect_statement_count 1 do
          unloaded_post.tags.delete('two')
          unloaded_post.save
        end
        expect(subject[:tags]).to eq(Set['one', 'three'])
      end

      it 'applies delete post-hoc' do
        unloaded_post.tags.delete('two')
        expect(unloaded_post.tags).to eq(Set['one', 'three'])
      end
    end

    describe '#replace' do
      it 'replaces atomically' do
        post.tags.replace(Set['a', 'b'])
        post.save
        expect(subject[:tags]).to eq(Set['a', 'b'])
        expect(post.tags).to eq(Set['a', 'b'])
      end

      it 'casts before replacing' do
        post.tags.replace(Set[1, 2, :three])
        expect(post.tags).to eq(Set['1', '2', 'three'])
      end

      it 'replaces without reading' do
        expect_statement_count 1 do
          unloaded_post.tags.replace(Set['a', 'b'])
          unloaded_post.save
        end
        expect(subject[:tags]).to eq(Set['a', 'b'])
      end

      it 'applies delete post-hoc' do
        unloaded_post.tags.replace(Set['a', 'b'])
        expect(unloaded_post.tags).to eq(Set['a', 'b'])
      end
    end

    specify { expect { post.tags.add?('three') }.to raise_error(NoMethodError) }

    specify do 
      expect { post.tags.collect!(&:upcase) }
        .to raise_error(NoMethodError)
    end

    specify { expect { post.tags.delete?('two') }.to raise_error(NoMethodError) }

    specify do 
      expect { post.tags.delete_if { |s| s.starts_with?('t') } }
        .to raise_error(NoMethodError)
    end

    specify { expect { post.tags.flatten! }.to raise_error(NoMethodError) }

    specify do 
      expect { post.tags.keep_if { |s| s.starts_with?('t') } }
        .to raise_error(NoMethodError)
    end

    specify do 
      expect { post.tags.map!(&:upcase) }
        .to raise_error(NoMethodError)
    end

    specify do 
      expect { post.tags.reject! { |s| s.starts_with?('t') } }
        .to raise_error(NoMethodError)
    end

    specify do 
      expect { post.tags.select! { |s| s.starts_with?('t') } }
        .to raise_error(NoMethodError)
    end
  end
end
