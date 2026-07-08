require File.expand_path('spec_helper', __dir__)

describe Cequel::Record::List do
  model :Post do
    key :permalink, :text
    column :title, :text
    list :tags, :text
    list :contributor_ids, :int
  end

  subject { scope.first }

  let(:scope) { cequel[Post.table_name].where(permalink: 'cequel') }
  let! :post do
    Post.new do |post|
      post.permalink = 'cequel'
      post.tags = %w[one two]
      post.contributor_ids = [1, 2]
    end.tap(&:save)
  end
  let! :unloaded_post do
    Post['cequel']
  end

  context 'new record' do
    it 'saves list as-is' do
      expect(subject[:tags]).to eq(%w[one two])
    end
  end

  context 'updating' do
    it 'overwrites value' do
      post.tags = %w[three four]
      post.save!
      expect(subject[:tags]).to eq(%w[three four])
    end

    it 'casts collection before overwriting' do
      post.tags = Set['three', 'four']
      post.save!
      expect(subject[:tags]).to eq(%w[three four])
    end
  end

  describe '#<<' do
    it 'does not re-apply after creation' do
      post = Post.new(permalink: 'cequel')
      post.tags << 'one'
      post.save!
      post.tags << 'two'
      post.save!
      expect(subject[:tags]).to eq(%w[one two])
    end

    it 'adds new items' do
      post.tags << 'three' << 'four'
      post.save
      expect(subject[:tags]).to eq(%w[one two three four])
    end

    it 'adds new items atomically' do
      scope.list_append(:tags, 'three')
      post.tags << 'four' << 'five'
      post.save
      expect(subject[:tags]).to eq(%w[one two three four five])
    end

    it 'adds new items without reading' do
      unloaded_post.tags << 'four' << 'five'
      unloaded_post.save
      expect(unloaded_post).not_to be_loaded
      expect(subject[:tags]).to eq(%w[one two four five])
    end

    it 'loads itself and then add new items in memory when unloaded' do
      unloaded_post.tags << 'four' << 'five'
      expect(unloaded_post.tags).to eq(%w[one two four five])
    end

    it 'casts to defined value' do
      post.contributor_ids << '3' << 4.0
      expect(post.contributor_ids).to eq([1, 2, 3, 4])
    end
  end

  describe '#[]=' do
    before { scope.list_append(:tags, 'three') }

    it 'atomicallies replace a single element' do
      post.tags[1] = 'TWO'
      post.save
      expect(subject[:tags]).to eq(%w[one TWO three])
      expect(post.tags).to eq(%w[one TWO])
    end

    it 'casts element before replacing' do
      post.contributor_ids[1] = '5'
      expect(post.contributor_ids).to eq([1, 5])
    end

    it 'replaces an element without reading' do
      disallow_queries!
      unloaded_post.tags[1] = 'TWO'
    end

    it 'persists the replaced element' do
      unloaded_post.tags[1] = 'TWO'
      unloaded_post.save
      expect(subject[:tags]).to eq(%w[one TWO three])
    end

    it 'applies local modifications when loaded later' do
      unloaded_post.tags[1] = 'TWO'
      expect(unloaded_post.tags).to eq(%w[one TWO three])
    end

    it 'atomicallies replace a given number of arguments' do
      post.tags[0, 2] = 'One', 'Two'
      post.save
      expect(subject[:tags]).to eq(%w[One Two three])
      expect(post.tags).to eq(%w[One Two])
    end

    it 'casts multiple elements before replacing them' do
      post.contributor_ids[0, 2] = %w[4 5]
      expect(post.contributor_ids).to eq([4, 5])
    end

    it 'removes elements beyond positional arguments' do
      scope.list_append(:tags, 'four')
      post.tags[0, 3] = 'ONE'
      post.save
      expect(subject[:tags]).to eq(%w[ONE four])
      expect(post.tags).to eq(%w[ONE])
    end

    it 'atomicallies replace a given range of elements' do
      post.tags[0..1] = %w[One Two]
      post.save
      expect(subject[:tags]).to eq(%w[One Two three])
      expect(post.tags).to eq(%w[One Two])
    end

    it 'removes elements beyond positional arguments' do
      scope.list_append(:tags, 'four')
      post.tags[0..2] = 'ONE'
      post.save
      expect(subject[:tags]).to eq(%w[ONE four])
      expect(post.tags).to eq(%w[ONE])
    end
  end

  describe '#clear' do
    it 'clears all elements from the array' do
      post.tags.clear
      post.save
      expect(subject[:tags]).to be_blank
      expect(post.tags).to eq([])
    end

    it 'clears elements without loading' do
      expect(cequel).not_to receive(:execute)
      unloaded_post.tags.clear
    end

    it 'persists clear without loading' do
      unloaded_post.tags.clear
      unloaded_post.save
      expect(subject[:tags]).to be_blank
    end

    it 'applies local modifications post-hoc' do
      unloaded_post.tags.clear
      expect(unloaded_post.tags).to eq([])
    end
  end

  describe '#collect!' do
    it 'does not respond' do
      expect { post.tags.collect!(&:upcase) }.to raise_error(NoMethodError)
    end
  end

  describe '#concat' do
    it 'atomicallies concatenate elements' do
      scope.list_append(:tags, 'three')
      post.tags.concat(%w[four five])
      post.save
      expect(subject[:tags]).to eq(%w[one two three four five])
      expect(post.tags).to eq(%w[one two four five])
    end

    it 'casts elements before concatentating' do
      post.contributor_ids.concat(%w[3 4])
      expect(post.contributor_ids).to eq([1, 2, 3, 4])
    end

    it 'concats elements without loading' do
      disallow_queries!
      unloaded_post.tags.concat(%w[four five])
    end

    it 'persists concatenated elements' do
      unloaded_post.tags.concat(%w[four five])
      unloaded_post.save
      expect(subject[:tags]).to eq(%w[one two four five])
    end

    it 'applies local modifications when loaded later' do
      unloaded_post.tags.concat(%w[four five])
      expect(unloaded_post.tags).to eq(%w[one two four five])
    end
  end

  describe '#delete' do
    it 'atomicallies delete all instances of an object' do
      scope.list_append(:tags, 'three')
      scope.list_append(:tags, 'two')
      post.tags.delete('two')
      post.save
      expect(subject[:tags]).to eq(%w[one three])
      expect(post.tags).to eq(%w[one])
    end

    it 'casts argument' do
      post.contributor_ids.delete('2')
      expect(post.contributor_ids).to eq([1])
    end

    it 'deletes without loading' do
      disallow_queries!
      unloaded_post.tags.delete('two')
    end

    it 'persists deletions without loading' do
      unloaded_post.tags.delete('two')
      unloaded_post.save
      expect(subject[:tags]).to eq(%w[one])
    end

    it 'modifies local copy after the fact' do
      unloaded_post.tags.delete('two')
      expect(unloaded_post.tags).to eq(%w[one])
    end
  end

  describe '#delete_at' do
    it 'atomicallies delete from a given index' do
      scope.list_append(:tags, %w[three four])
      post.tags.delete_at(1)
      post.save
      expect(subject[:tags]).to eq(%w[one three four])
      expect(post.tags).to eq(%w[one])
    end

    it 'deletes from a given index without reading' do
      disallow_queries!
      unloaded_post.tags.delete_at(1)
    end

    it 'persists deletion from unloaded list' do
      unloaded_post.tags.delete_at(1)
      unloaded_post.save
      expect(subject[:tags]).to eq(%w[one])
    end

    it 'applies deletion after the fact' do
      unloaded_post.tags.delete_at(1)
      expect(unloaded_post.tags).to eq(%w[one])
    end
  end

  describe '#delete_if' do
    it 'does not respond' do
      expect { post.tags.delete_if { |tag| tag.start_with?('o') } }
        .to raise_error(NoMethodError)
    end
  end

  describe '#fill' do
    it 'does not respond' do
      expect { post.tags.fill('seventy') }.to raise_error(NoMethodError)
    end
  end

  describe '#flatten!' do
    it 'does not respond' do
      expect { post.tags.flatten! }.to raise_error(NoMethodError)
    end
  end

  describe '#insert' do
    it 'does not respond' do
      expect { post.tags.insert(4, 'five') }.to raise_error(NoMethodError)
    end
  end

  describe '#keep_if' do
    it 'does not respond' do
      expect { post.tags.keep_if { |e| e.start_with?('o') } }
        .to raise_error(NoMethodError)
    end
  end

  describe '#map!' do
    it 'does not respond' do
      expect { post.tags.map! { |e| e.upcase } }
        .to raise_error(NoMethodError)
    end
  end

  describe '#pop' do
    it 'does not respond' do
      expect { post.tags.pop }.to raise_error(NoMethodError)
    end
  end

  describe '#push' do
    it 'adds new items atomically' do
      scope.list_append(:tags, 'three')
      post.tags.push('four').push('five')
      post.save
      expect(subject[:tags]).to eq(%w[one two three four five])
      expect(post.tags).to eq(%w[one two four five])
    end
  end

  describe '#reject!' do
    it 'does not respond' do
      expect { post.tags.reject! { |e| e.start_with?('o') } }
        .to raise_error(NoMethodError)
    end
  end

  describe '#replace' do
    it 'justs overwrite the whole array' do
      scope.list_append(:tags, 'three')
      post.tags.replace(%w[four five])
      post.save
      expect(subject[:tags]).to eq(%w[four five])
      expect(post.tags).to eq(%w[four five])
    end

    it 'casts before overwriting' do
      post.contributor_ids.replace(%w[3 4 5])
      expect(post.contributor_ids).to eq([3, 4, 5])
    end

    it 'overwrites without reading' do
      disallow_queries!
      unloaded_post.tags.replace(%w[four five])
    end

    it 'persists unloaded overwrite' do
      unloaded_post.tags.replace(%w[four five])
      unloaded_post.save
      expect(subject[:tags]).to eq(%w[four five])
    end

    it 'applies replace post-hoc' do
      unloaded_post.tags.replace(%w[four five])
      expect(unloaded_post.tags).to eq(%w[four five])
    end
  end

  describe '#reverse!' do
    it 'does not respond' do
      expect { post.tags.reverse! }.to raise_error(NoMethodError)
    end
  end

  describe '#rotate!' do
    it 'does not respond' do
      expect { post.tags.rotate! }.to raise_error(NoMethodError)
    end
  end

  describe '#select!' do
    it 'does not respond' do
      expect { post.tags.select! { |e| e.start_with?('o') } }
        .to raise_error(NoMethodError)
    end
  end

  describe '#shift' do
    it 'does not respond' do
      expect { post.tags.shift }.to raise_error(NoMethodError)
    end
  end

  describe '#shuffle!' do
    it 'does not respond' do
      expect { post.tags.shuffle! }.to raise_error(NoMethodError)
    end
  end

  describe '#slice!' do
    it 'does not respond' do
      expect { post.tags.slice!(1, 2) }.to raise_error(NoMethodError)
    end
  end

  describe '#sort!' do
    it 'does not respond' do
      expect { post.tags.sort! }.to raise_error(NoMethodError)
    end
  end

  describe '#sort_by!' do
    it 'does not respond' do
      expect { post.tags.sort_by! { |e| e.reverse } }
        .to raise_error(NoMethodError)
    end
  end

  describe '#uniq!' do
    it 'does not respond' do
      expect { post.tags.uniq! }.to raise_error(NoMethodError)
    end
  end

  describe '#unshift' do
    it 'atomicallies unshift' do
      scope.list_prepend(:tags, 'zero')
      post.tags.unshift('minustwo', 'minusone')
      post.save
      expect(subject[:tags]).to eq(%w[minustwo minusone zero one two])
      expect(post.tags).to eq(%w[minustwo minusone one two])
    end

    it 'casts element before unshifting' do
      post.contributor_ids.unshift('0')
      expect(post.contributor_ids).to eq([0, 1, 2])
    end

    it 'unshifts without reading' do
      disallow_queries!
      unloaded_post.tags.unshift('minustwo', 'minusone')
    end

    it 'persists unloaded unshift' do
      unloaded_post.tags.unshift('minustwo', 'minusone')
      unloaded_post.save
      expect(subject[:tags]).to eq(%w[minustwo minusone one two])
    end

    it 'applies unshift after the fact' do
      unloaded_post.tags.unshift('minustwo', 'minusone')
      expect(unloaded_post.tags).to eq(%w[minustwo minusone one two])
    end
  end
end
