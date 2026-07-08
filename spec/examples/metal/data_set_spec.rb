require File.expand_path('../spec_helper', __dir__)

describe Cequel::Metal::DataSet do
  posts_tn = "posts_#{SecureRandom.hex(4)}"
  post_act_tn = "post_activity_#{SecureRandom.hex(4)}" 

  before :all do
    cequel.schema.create_table(posts_tn) do
      key :blog_subdomain, :text
      key :permalink, :text
      column :title, :text
      column :body, :text
      column :published_at, :timestamp
      list :categories, :text
      set :tags, :text
      map :trackbacks, :timestamp, :text
    end
    cequel.schema.create_table post_act_tn do
      key :blog_subdomain, :text
      key :permalink, :text
      column :visits, :counter
      column :tweets, :counter
    end
  end

  after do
    subdomains = cequel[posts_tn].select(:blog_subdomain)
                                 .map { |row| row[:blog_subdomain] }
    cequel[posts_tn].where(blog_subdomain: subdomains).delete if subdomains.any?
  end

  after :all do
    cequel.schema.drop_table(posts_tn)
    cequel.schema.drop_table(post_act_tn)
  end

  let(:row_keys) { {blog_subdomain: 'cassandra', permalink: 'big-data'} }

  describe '#insert' do
    let(:row) do
      row_keys.merge(
        title: 'Fun times',
        categories: %w[Fun Profit],
        tags: Set['cassandra', 'big-data'],
        trackbacks: {
          Time.at(Time.now.to_i) => 'www.google.com',
          Time.at(Time.now.to_i - 60) => 'www.yahoo.com'
        }
      )
    end

    it 'inserts a row' do
      cequel[posts_tn].insert(row)
      expect(cequel[posts_tn].where(row_keys).first[:title]).to eq('Fun times')
    end

    it 'correctlies insert a list' do
      cequel[posts_tn].insert(row)
      expect(cequel[posts_tn].where(row_keys).first[:categories])
        .to eq(%w[Fun Profit])
    end

    it 'correctlies insert a set' do
      cequel[posts_tn].insert(row)
      expect(cequel[posts_tn].where(row_keys).first[:tags])
        .to eq(Set['cassandra', 'big-data'])
    end

    it 'correctlies insert a map' do
      cequel[posts_tn].insert(row)
      expect(cequel[posts_tn].where(row_keys).first[:trackbacks])
        .to eq(row[:trackbacks])
    end

    it 'includes ttl argument' do
      cequel[posts_tn].insert(row, ttl: 10.minutes)
      expect(cequel[posts_tn].select_ttl(:title).where(row_keys).first.ttl(:title))
        .to be_within(5).of(10.minutes)
    end

    it 'includes timestamp argument' do
      cequel.schema.truncate_table(posts_tn)
      time = 1.day.ago
      cequel[posts_tn].insert(row, timestamp: time)
      expect(cequel[posts_tn].select_writetime(:title).where(row_keys)
        .first.writetime(:title)).to eq((time.to_f * 1_000_000).to_i)
    end

    it 'inserts row with given consistency' do
      expect_query_with_consistency(->(s) { /INSERT/ === s.cql }, :one) do
        cequel[posts_tn].insert(row, consistency: :one)
      end
    end

    it 'includes multiple arguments joined by AND' do
      cequel.schema.truncate_table(posts_tn)
      time = 1.day.ago
      cequel[posts_tn].insert(row, ttl: 600, timestamp: time)
      result = cequel[posts_tn].select_ttl(:title).select_writetime(:title)
                               .where(row_keys).first
      expect(result.writetime(:title)).to eq((time.to_f * 1_000_000).to_i)
      expect(result.ttl(:title)).to be_within(5).of(10.minutes)
    end
  end

  describe '#update' do
    it 'sends basic update statement' do
      cequel[posts_tn].where(row_keys)
                      .update(title: 'Fun times', body: 'Fun')
      expect(cequel[posts_tn].where(row_keys)
        .first[:title]).to eq('Fun times')
    end

    it 'sends update statement with options' do
      cequel.schema.truncate_table(posts_tn)
      time = Time.now - 10.minutes

      cequel[posts_tn].where(row_keys)
                      .update({title: 'Fun times', body: 'Fun'}, ttl: 600, timestamp: time)

      row = cequel[posts_tn]
            .select_ttl(:title).select_writetime(:title)
            .where(row_keys).first

      expect(row.ttl(:title)).to be_within(5).of(10.minutes)
      expect(row.writetime(:title)).to eq((time.to_f * 1_000_000).to_i)
    end

    it 'sends update statement with given consistency' do
      expect_query_with_consistency(->(s) { /UPDATE/ === s.cql }, :one) do
        cequel[posts_tn].where(row_keys).update(
          {title: 'Marshmallows'}, consistency: :one
        )
      end
    end

    it 'overwrites list column' do
      cequel[posts_tn].where(row_keys)
                      .update(categories: ['Big Data', 'Cassandra'])
      expect(cequel[posts_tn].where(row_keys).first[:categories])
        .to eq(['Big Data', 'Cassandra'])
    end

    it 'overwrites set column' do
      cequel[posts_tn].where(row_keys).update(tags: Set['big-data', 'nosql'])
      expect(cequel[posts_tn].where(row_keys).first[:tags])
        .to eq(Set['big-data', 'nosql'])
    end

    it 'overwrites map column' do
      time1 = Time.at(Time.now.to_i)
      time2 = Time.at(10.minutes.ago.to_i)
      cequel[posts_tn].where(row_keys).update(
        trackbacks: {time1 => 'foo', time2 => 'bar'}
      )
      expect(cequel[posts_tn].where(row_keys).first[:trackbacks])
        .to eq({time1 => 'foo', time2 => 'bar'})
    end

    it 'performs various types of update in one go' do
      cequel[posts_tn].insert(
        row_keys.merge(title: 'Big Data',
                       body: 'Cassandra',
                       categories: ['Scalability'])
      )
      cequel[posts_tn].where(row_keys).update do
        set(title: 'Bigger Data')
        list_append(:categories, 'Fault-Tolerance')
      end
      expect(cequel[posts_tn].where(row_keys).first[:title]).to eq('Bigger Data')
      expect(cequel[posts_tn].where(row_keys).first[:categories])
        .to eq(%w[Scalability Fault-Tolerance])
    end

    it 'uses the last value set for a given column' do
      cequel[posts_tn].insert(
        row_keys.merge(title: 'Big Data',
                       body: 'Cassandra',
                       categories: ['Scalability'])
      )
      cequel[posts_tn].where(row_keys).update do
        set(title: 'Bigger Data')
        set(title: 'Even Bigger Data')
      end
      expect(cequel[posts_tn].where(row_keys).first[:title]).to eq('Even Bigger Data')
    end
  end

  describe '#list_prepend' do
    it 'prepends a single element to list column' do
      cequel[posts_tn].insert(
        row_keys.merge(categories: ['Big Data', 'Cassandra'])
      )
      cequel[posts_tn].where(row_keys)
                      .list_prepend(:categories, 'Scalability')
      expect(cequel[posts_tn].where(row_keys).first[:categories]).to eq(
        ['Scalability', 'Big Data', 'Cassandra']
      )
    end

    # breaks in Cassandra 2.0.13+ or 2.1.3+ because reverse order bug was fixed:
    # https://issues.apache.org/jira/browse/CASSANDRA-8733
    it 'prepends multiple elements to list column' do
      cequel[posts_tn].insert(
        row_keys.merge(categories: ['Big Data', 'Cassandra'])
      )
      cequel[posts_tn].where(row_keys)
                      .list_prepend(:categories, ['Scalability', 'Partition Tolerance'])

      expected = if cequel.bug8733_version?
                   ['Partition Tolerance', 'Scalability', 'Big Data', 'Cassandra']
                 else
                   ['Scalability', 'Partition Tolerance', 'Big Data', 'Cassandra']
                 end

      expect(cequel[posts_tn].where(row_keys).first[:categories]).to eq(expected)
    end
  end

  describe '#list_append' do
    it 'appends single element to list column' do
      cequel[posts_tn].insert(
        row_keys.merge(categories: ['Big Data', 'Cassandra'])
      )
      cequel[posts_tn].where(row_keys)
                      .list_append(:categories, 'Scalability')
      expect(cequel[posts_tn].where(row_keys).first[:categories]).to eq(
        ['Big Data', 'Cassandra', 'Scalability']
      )
    end

    it 'appends multiple elements to list column' do
      cequel[posts_tn].insert(
        row_keys.merge(categories: ['Big Data', 'Cassandra'])
      )
      cequel[posts_tn].where(row_keys)
                      .list_append(:categories, ['Scalability', 'Partition Tolerance'])
      expect(cequel[posts_tn].where(row_keys).first[:categories]).to eq(
        ['Big Data', 'Cassandra', 'Scalability', 'Partition Tolerance']
      )
    end
  end

  describe '#list_replace' do
    it 'adds to list at specified index' do
      cequel[posts_tn].insert(
        row_keys.merge(categories: ['Big Data', 'Cassandra', 'Scalability'])
      )
      cequel[posts_tn].where(row_keys)
                      .list_replace(:categories, 1, 'C*')
      expect(cequel[posts_tn].where(row_keys).first[:categories]).to eq(
        ['Big Data', 'C*', 'Scalability']
      )
    end
  end

  describe '#list_remove' do
    it 'removes from list by specified value' do
      cequel[posts_tn].insert(
        row_keys.merge(categories: ['Big Data', 'Cassandra', 'Scalability'])
      )
      cequel[posts_tn].where(row_keys)
                      .list_remove(:categories, 'Cassandra')
      expect(cequel[posts_tn].where(row_keys).first[:categories]).to eq(
        ['Big Data', 'Scalability']
      )
    end

    it 'removes from list by multiple values' do
      cequel[posts_tn].insert(
        row_keys.merge(categories: ['Big Data', 'Cassandra', 'Scalability'])
      )
      cequel[posts_tn].where(row_keys)
                      .list_remove(:categories, ['Big Data', 'Cassandra'])
      expect(cequel[posts_tn].where(row_keys).first[:categories]).to eq(
        ['Scalability']
      )
    end
  end

  describe '#set_add' do
    it 'adds one element to set' do
      cequel[posts_tn].insert(
        row_keys.merge(tags: Set['big-data', 'nosql'])
      )
      cequel[posts_tn].where(row_keys).set_add(:tags, 'cassandra')
      expect(cequel[posts_tn].where(row_keys).first[:tags])
        .to eq(Set['big-data', 'nosql', 'cassandra'])
    end

    it 'adds multiple elements to set' do
      cequel[posts_tn].insert(row_keys.merge(tags: Set['big-data', 'nosql']))
      cequel[posts_tn].where(row_keys).set_add(:tags, 'cassandra')

      expect(cequel[posts_tn].where(row_keys).first[:tags])
        .to eq(Set['big-data', 'nosql', 'cassandra'])
    end
  end

  describe '#set_remove' do
    it 'removes elements from set' do
      cequel[posts_tn].insert(
        row_keys.merge(tags: Set['big-data', 'nosql', 'cassandra'])
      )
      cequel[posts_tn].where(row_keys).set_remove(:tags, 'cassandra')
      expect(cequel[posts_tn].where(row_keys).first[:tags])
        .to eq(Set['big-data', 'nosql'])
    end

    it 'removes multiple elements from set' do
      cequel[posts_tn].insert(
        row_keys.merge(tags: Set['big-data', 'nosql', 'cassandra'])
      )
      cequel[posts_tn].where(row_keys)
                      .set_remove(:tags, Set['nosql', 'cassandra'])
      expect(cequel[posts_tn].where(row_keys).first[:tags])
        .to eq(Set['big-data'])
    end
  end

  describe '#map_update' do
    it 'updates specified map key with value' do
      time1 = Time.at(Time.now.to_i)
      time2 = Time.at(10.minutes.ago.to_i)
      time3 = Time.at(1.hour.ago.to_i)
      cequel[posts_tn].insert(row_keys.merge(
                                trackbacks: {time1 => 'foo', time2 => 'bar'}
                              ))
      cequel[posts_tn].where(row_keys).map_update(:trackbacks, time3 => 'baz')
      expect(cequel[posts_tn].where(row_keys).first[:trackbacks])
        .to eq({time1 => 'foo', time2 => 'bar', time3 => 'baz'})
    end

    it 'updates specified map key with multiple values' do
      time1 = Time.at(Time.now.to_i)
      time2 = Time.at(10.minutes.ago.to_i)
      time3 = Time.at(1.hour.ago.to_i)
      cequel[posts_tn].insert(row_keys.merge(
                                trackbacks: {time1 => 'foo', time2 => 'bar'}
                              ))
      cequel[posts_tn].where(row_keys)
                      .map_update(:trackbacks, time1 => 'FOO', time3 => 'baz')
      expect(cequel[posts_tn].where(row_keys).first[:trackbacks])
        .to eq({time1 => 'FOO', time2 => 'bar', time3 => 'baz'})
    end
  end

  describe '#increment' do
    after { cequel.schema.truncate_table(post_act_tn) }

    it 'increments counter columns' do
      cequel[post_act_tn]
        .where(row_keys)
        .increment(visits: 1, tweets: 2)

      row = cequel[post_act_tn].where(row_keys).first

      expect(row[:visits]).to eq(1)
      expect(row[:tweets]).to eq(2)
    end
  end

  describe '#decrement' do
    after { cequel.schema.truncate_table(post_act_tn) }

    it 'decrements counter columns' do
      cequel[post_act_tn].where(row_keys)
                         .decrement(visits: 1, tweets: 2)

      row = cequel[post_act_tn].where(row_keys).first
      expect(row[:visits]).to eq(-1)
      expect(row[:tweets]).to eq(-2)
    end
  end

  describe '#delete' do
    before do
      cequel[posts_tn]
        .insert(row_keys.merge(title: 'Big Data', body: 'It\'s big.'))
    end

    it 'sends basic delete statement' do
      cequel[posts_tn].where(row_keys).delete
      expect(cequel[posts_tn].where(row_keys).first).to be_nil
    end

    it 'sends delete statement for specified columns' do
      cequel[posts_tn].where(row_keys).delete(:body)
      row = cequel[posts_tn].where(row_keys).first
      expect(row[:body]).to be_nil
      expect(row[:title]).to eq('Big Data')
    end

    it 'sends delete statement with writetime option' do
      time = Time.now - 10.minutes

      cequel[posts_tn].where(row_keys).delete(
        :body, timestamp: time
      )
      row = cequel[posts_tn].select(:body).where(row_keys).first
      expect(row[:body]).to eq('It\'s big.')
      # This means timestamp is working, since the earlier timestamp would cause
      # Cassandra to ignore the deletion
    end

    it 'sends delete with specified consistency' do
      expect_query_with_consistency(->(s) { /DELETE/ === s.cql }, :one) do
        cequel[posts_tn].where(row_keys).delete(:body, consistency: :one)
      end
    end
  end

  describe '#list_remove_at' do
    it 'removes element at specified position from list' do
      cequel[posts_tn]
        .insert(row_keys.merge(categories: ['Big Data', 'NoSQL', 'Cassandra']))
      cequel[posts_tn].where(row_keys).list_remove_at(:categories, 1)
      expect(cequel[posts_tn].where(row_keys).first[:categories])
        .to eq(['Big Data', 'Cassandra'])
    end

    it 'removes element at specified positions from list' do
      cequel[posts_tn]
        .insert(row_keys.merge(categories: ['Big Data', 'NoSQL', 'Cassandra']))
      cequel[posts_tn].where(row_keys).list_remove_at(:categories, 0, 2)
      expect(cequel[posts_tn].where(row_keys).first[:categories])
        .to eq(['NoSQL'])
    end
  end

  describe '#map_remove' do
    it 'removes one element from a map' do
      time1 = Time.at(Time.now.to_i)
      time2 = Time.at(10.minutes.ago.to_i)
      time3 = Time.at(1.hour.ago.to_i)
      cequel[posts_tn].insert(row_keys.merge(
                                trackbacks: {time1 => 'foo', time2 => 'bar', time3 => 'baz'}
                              ))
      cequel[posts_tn].where(row_keys).map_remove(:trackbacks, time2)
      expect(cequel[posts_tn].where(row_keys).first[:trackbacks])
        .to eq({time1 => 'foo', time3 => 'baz'})
    end

    it 'removes multiple elements from a map' do
      time1 = Time.at(Time.now.to_i)
      time2 = Time.at(10.minutes.ago.to_i)
      time3 = Time.at(1.hour.ago.to_i)
      cequel[posts_tn].insert(row_keys.merge(
                                trackbacks: {time1 => 'foo', time2 => 'bar', time3 => 'baz'}
                              ))
      cequel[posts_tn].where(row_keys).map_remove(:trackbacks, time1, time3)
      expect(cequel[posts_tn].where(row_keys).first[:trackbacks])
        .to eq({time2 => 'bar'})
    end
  end

  describe '#cql' do
    it 'generates select statement with all columns' do
      expect(cequel[posts_tn].cql.to_s).to eq("SELECT * FROM #{posts_tn}")
    end
  end

  describe '#select' do
    before do
      cequel[posts_tn].insert(row_keys.merge(
                                title: 'Big Data',
                                body: 'Fault Tolerance',
                                published_at: Time.now
                              ))
    end

    it 'generates select statement with given columns' do
      expect(cequel[posts_tn].select(:title, :body).where(row_keys).first
        .keys).to eq(%w[title body])
    end

    it 'accepts array argument' do
      expect(cequel[posts_tn].select(%i[title body]).where(row_keys).first
        .keys).to eq(%w[title body])
    end

    it 'combines multiple selects' do
      expect(cequel[posts_tn].select(:title).select(:body).where(row_keys).first
        .keys).to eq(%w[title body])
    end
  end

  describe '#select!' do
    before do
      cequel[posts_tn].insert(row_keys.merge(
                                title: 'Big Data',
                                body: 'Fault Tolerance',
                                published_at: Time.now
                              ))
    end

    it 'overrides select statement with given columns' do
      expect(cequel[posts_tn].select(:title, :body).select!(:published_at)
        .where(row_keys).first.keys).to eq(%w[published_at])
    end
  end

  describe '#where' do
    before do
      cequel[posts_tn].insert(row_keys.merge(
                                title: 'Big Data',
                                body: 'Fault Tolerance',
                                published_at: Time.now
                              ))
    end

    it 'builds WHERE statement from hash' do
      expect(cequel[posts_tn].where(blog_subdomain: row_keys[:blog_subdomain])
        .first[:title]).to eq('Big Data')
      expect(cequel[posts_tn].where(blog_subdomain: 'foo').first).to be_nil
    end

    it 'builds WHERE statement from multi-element hash' do
      expect(cequel[posts_tn].where(row_keys).first[:title]).to eq('Big Data')
      expect(cequel[posts_tn].where(row_keys.merge(permalink: 'foo'))
        .first).to be_nil
    end

    it 'builds WHERE statement with IN' do
      cequel[posts_tn].insert(row_keys.merge(
                                blog_subdomain: 'big-data-weekly',
                                title: 'Cassandra'
                              ))
      cequel[posts_tn].insert(row_keys.merge(
                                blog_subdomain: 'bogus-blog',
                                title: 'Bogus Post'
                              ))
      expect(cequel[posts_tn].where(
        blog_subdomain: %w[cassandra big-data-weekly]
      ).map { |row| row[:title] }).to contain_exactly('Big Data', 'Cassandra')
    end

    it 'uses = if provided one-element array' do
      expect(cequel[posts_tn]
        .where(row_keys.merge(blog_subdomain: [row_keys[:blog_subdomain]]))
        .first[:title]).to eq('Big Data')
    end

    it 'builds WHERE statement from CQL string' do
      expect(cequel[posts_tn].where("blog_subdomain = '#{row_keys[:blog_subdomain]}'")
        .first[:title]).to eq('Big Data')
    end

    it 'builds WHERE statement from CQL string with bind variables' do
      expect(cequel[posts_tn].where("blog_subdomain = ?", row_keys[:blog_subdomain])
        .first[:title]).to eq('Big Data')
    end

    it 'aggregates multiple WHERE statements' do
      expect(cequel[posts_tn].where(blog_subdomain: row_keys[:blog_subdomain])
        .where('permalink = ?', row_keys[:permalink])
        .first[:title]).to eq('Big Data')
    end

  end

  describe '#where!' do
    before do
      cequel[posts_tn].insert(row_keys.merge(
                                title: 'Big Data',
                                body: 'Fault Tolerance',
                                published_at: Time.now
                              ))
    end

    it 'overrides chained conditions' do
      expect(cequel[posts_tn].where(permalink: 'bogus')
        .where!(blog_subdomain: row_keys[:blog_subdomain])
        .first[:title]).to eq('Big Data')
    end
  end

  describe '#limit' do
    before do
      cequel[posts_tn].insert(row_keys.merge(title: 'Big Data'))
      cequel[posts_tn].insert(
        row_keys.merge(permalink: 'marshmallows', title: 'Marshmallows')
      )
      cequel[posts_tn].insert(
        row_keys.merge(permalink: 'zz-top', title: 'ZZ Top')
      )
    end

    it 'adds LIMIT' do
      expect(cequel[posts_tn].where(row_keys.slice(:blog_subdomain)).limit(2)
        .map { |row| row[:title] }).to eq(['Big Data', 'Marshmallows'])
    end
  end

  describe '#order' do
    before do
      cequel[posts_tn].insert(row_keys.merge(title: 'Big Data'))
      cequel[posts_tn].insert(
        row_keys.merge(permalink: 'marshmallows', title: 'Marshmallows')
      )
      cequel[posts_tn].insert(
        row_keys.merge(permalink: 'zz-top', title: 'ZZ Top')
      )
    end

    it 'adds order' do
      expect(cequel[posts_tn].where(row_keys.slice(:blog_subdomain))
        .order(permalink: 'desc').map { |row| row[:title] })
        .to eq(['ZZ Top', 'Marshmallows', 'Big Data'])
    end
  end

  describe '#consistency' do
    let(:data_set) { cequel[posts_tn].consistency(:one) }

    it 'issues SELECT with scoped consistency' do
      expect_query_with_consistency(anything, :one) { data_set.to_a }
    end

    it 'issues INSERT with scoped consistency' do
      expect_query_with_consistency(anything, :one) do
        data_set.insert(row_keys)
      end
    end

    it 'issues UPDATE with scoped consistency' do
      expect_query_with_consistency(anything, :one) do
        data_set.where(row_keys).update(title: 'Marshmallows')
      end
    end

    it 'issues DELETE with scoped consistency' do
      expect_query_with_consistency(anything, :one) do
        data_set.where(row_keys).delete
      end
    end

    it 'issues DELETE column with scoped consistency' do
      expect_query_with_consistency(anything, :one) do
        data_set.where(row_keys).delete(:title)
      end
    end
  end

  describe 'default consistency' do
    before(:all) { cequel.default_consistency = :all }
    after(:all) { cequel.default_consistency = nil }

    let(:data_set) { cequel[posts_tn] }

    it 'issues SELECT with default consistency' do
      expect_query_with_consistency(anything, :all) { data_set.to_a }
    end

    it 'issues INSERT with default consistency' do
      expect_query_with_consistency(anything, :all) do
        data_set.insert(row_keys)
      end
    end

    it 'issues UPDATE with default consistency' do
      expect_query_with_consistency(anything, :all) do
        data_set.where(row_keys).update(title: 'Marshmallows')
      end
    end

    it 'issues DELETE with default consistency' do
      expect_query_with_consistency(anything, :all) do
        data_set.where(row_keys).delete
      end
    end

    it 'issues DELETE column with default consistency' do
      expect_query_with_consistency(anything, :all) do
        data_set.where(row_keys).delete(:title)
      end
    end
  end

  describe '#page_size' do
    let(:data_set) { cequel[posts_tn].page_size(1) }

    it 'issues SELECT with scoped page size' do
      expect_query_with_options(->(s) { /SELECT/ === s.cql }, page_size: 1) { data_set.to_a }
    end
  end

  describe '#paging_state' do
    let(:data_set) { cequel[posts_tn].paging_state(nil) }

    it 'issues SELECT with scoped paging state' do
      expect_query_with_options(->(s) { /SELECT/ === s.cql }, paging_state: nil) { data_set.to_a }
    end
  end

  describe 'result enumeration' do
    let(:row) { row_keys.merge(title: 'Big Data') }

    before do
      cequel[posts_tn].insert(row)
    end

    it 'enumerates over results' do
      expect(cequel[posts_tn].to_a.map { |row| row.select { |k, v| v } })
        .to eq([row.stringify_keys])
    end

    it 'provides results with indifferent access' do
      expect(cequel[posts_tn].to_a.first[:blog_permalink])
        .to eq(row_keys[:blog_permalink])
    end

    it 'does not run query if no block given to #each' do
      expect { cequel[posts_tn].each }.not_to raise_error
    end

    it 'returns Enumerator if no block given to #each' do
      expect(cequel[posts_tn].each.each_with_index
        .map { |row, i| [row[:blog_permalink], i] })
        .to eq([[row[:blog_permalink], 0]])
    end
  end

  describe '#first' do
    let(:row) { row_keys.merge(title: 'Big Data') }

    before do
      cequel[posts_tn].insert(row)
      cequel[posts_tn].insert(
        row_keys.merge(permalink: 'zz-top', title: 'ZZ Top')
      )
    end

    it 'runs a query with LIMIT 1 and return first row' do
      expect(cequel[posts_tn].first.select { |k, v| v }).to eq(row.stringify_keys)
    end
  end

  describe '#count' do
    before do
      4.times do |i|
        cequel[posts_tn].insert(row_keys.merge(
                                  permalink: "post-#{i}", title: "Post #{i}"
                                ))
      end
    end

    it 'raises DangerousQueryError when attempting to count' do
      expect { cequel[posts_tn].count }.to raise_error(Cequel::Record::DangerousQueryError)
    end

    it 'raises DangerousQueryError when attempting to access size' do
      expect { cequel[posts_tn].size }.to raise_error(Cequel::Record::DangerousQueryError)
    end

    it 'raises DangerousQueryError when attempting to access length' do
      expect { cequel[posts_tn].length }.to raise_error(Cequel::Record::DangerousQueryError)
    end
  end
end
