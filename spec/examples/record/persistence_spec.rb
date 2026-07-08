require File.expand_path('spec_helper', __dir__)

describe Cequel::Record::Persistence do
  model :Blog do
    key :subdomain, :text
    column :name, :text
    column :description, :text
    column :owner_id, :uuid
  end

  model :Post do
    key :blog_subdomain, :text
    key :permalink, :text
    column :title, :text
    column :body, :text
    column :author_id, :uuid
  end

  context 'simple keys' do
    subject { cequel[Blog.table_name].where(subdomain: 'cequel').first }

    let!(:blog) do
      Blog.new do |blog|
        blog.subdomain = 'cequel'
        blog.name = 'Cequel'
        blog.description = 'A Ruby ORM for Cassandra 1.2'
      end.tap(&:save)
    end

    describe 'new record' do
      specify { expect(Blog.new).not_to be_persisted }
      specify { expect(Blog.new).to be_transient }
    end

    describe '#save' do
      context 'on create' do
        it 'saves row to database' do
          expect(subject[:name]).to eq('Cequel')
        end

        it 'marks row persisted' do
          expect(blog).to be_persisted
        end

        it 'fails fast if keys are missing' do
          expect do
            Blog.new.save
          end.to raise_error(Cequel::Record::MissingKeyError)
        end

        it 'saves with specified consistency' do
          expect_query_with_consistency(anything, :one) do
            Blog.new do |blog|
              blog.subdomain = 'cequel'
              blog.name = 'Cequel'
            end.save(consistency: :one)
          end
        end

        it 'saves with specified TTL' do
          Blog.new(subdomain: 'cequel', name: 'Cequel').save(ttl: 10)
          expect(cequel[Blog.table_name].select_ttl(:name).first.ttl(:name))
            .to be_within(0.1).of(9.9)
        end

        it 'saves with specified timestamp' do
          timestamp = 1.minute.from_now
          Blog.new(subdomain: 'cequel-create-ts', name: 'Cequel')
              .save(timestamp: timestamp)
          expect(cequel[Blog.table_name].select_timestamp(:name).first.timestamp(:name))
            .to eq((timestamp.to_f * 1_000_000).to_i)
          Blog.connection.schema.truncate_table(Blog.table_name)
        end

        it 'notifies of create' do
          expect do 
            Blog.new do |blog|
              blog.subdomain = 'cequel'
              blog.name = 'Cequel'
            end.save
          end.to notify_name("create.cequel")
        end
      end

      context 'on update' do
        uuid :owner_id

        before do
          blog.name = 'Cequel 1.0'
          blog.owner_id = owner_id
          blog.description = nil
          blog.save
        end

        it 'changes existing column value' do
          expect(subject[:name]).to eq('Cequel 1.0')
        end

        it 'adds new column value' do
          expect(subject[:owner_id]).to eq(owner_id)
        end

        it 'removes old column values' do
          expect(subject[:description]).to be_nil
        end

        it 'does not allow changing key values' do
          expect do
            blog.subdomain = 'soup'
            blog.save
          end.to raise_error(ArgumentError)
        end

        it 'allows setting a key value to the same thing it already is' do
          expect do
            blog.subdomain = 'cequel'
            blog.save
          end.not_to raise_error
        end

        it 'saves with specified consistency' do
          expect_query_with_consistency(anything, :one) do
            blog.name = 'Cequel'
            blog.save(consistency: :one)
          end
        end

        it 'saves with specified TTL' do
          blog.name = 'Cequel 1.4'
          blog.save(ttl: 10)
          expect(cequel[Blog.table_name].select_ttl(:name).first.ttl(:name))
            .to be_between(9, 10).inclusive
        end

        it 'saves with specified timestamp' do
          timestamp = 1.minute.from_now
          blog.name = 'Cequel 1.4'
          blog.save(timestamp: timestamp)
          expect(cequel[Blog.table_name].select_timestamp(:name).first.timestamp(:name))
            .to eq((timestamp.to_f * 1_000_000).to_i)
          Blog.connection.schema.truncate_table(Blog.table_name)
        end

        it 'does not query database if no attributes have been changed' do
          disallow_queries!
          blog.save
        end

        it 'does not mark itself as clean if save failed at Cassandra level' do
          blog.name = 'Pizza'
          with_client_error(Cassandra::Errors::InvalidError.new(nil, nil, nil, nil, nil, nil, nil, nil, nil)) do
            
            blog.save
          rescue Cassandra::Errors::InvalidError
            
          end
          blog.save
          expect(subject[:name]).to eq('Pizza')
        end
      end
    end

    describe '::create' do
      uuid :owner_id

      describe 'with block' do
        let! :blog do
          Blog.create do |blog|
            blog.subdomain = 'big-data'
            blog.name = 'Big Data'
          end
        end

        it 'initializes with block' do
          expect(blog.name).to eq('Big Data')
        end

        it 'saves instance' do
          expect(Blog.find(blog.subdomain).name).to eq('Big Data')
        end

        it 'fails fast if keys are missing' do
          expect do
            Blog.create do |blog|
              blog.name = 'Big Data'
            end
          end.to raise_error(Cequel::Record::MissingKeyError)
        end
      end

      describe 'with attributes' do
        let!(:blog) do
          Blog.create(subdomain: 'big-data', name: 'Big Data')
        end

        it 'initializes with block' do
          expect(blog.name).to eq('Big Data')
        end

        it 'saves instance' do
          expect(Blog.find(blog.subdomain).name).to eq('Big Data')
        end

        it 'fails fast if keys are missing' do
          expect do
            Blog.create(name: 'Big Data')
          end.to raise_error(Cequel::Record::MissingKeyError)
        end
      end
    end

    describe '#update_attributes' do
      let! :blog do
        Blog.create(subdomain: 'big-data', name: 'Big Data')
      end

      before { blog.update_attributes(name: 'The Big Data Blog') }

      it 'updates instance in memory' do
        expect(blog.name).to eq('The Big Data Blog')
      end

      it 'saves instance' do
        expect(Blog.find(blog.subdomain).name).to eq('The Big Data Blog')
      end

      it 'does not allow updating key values' do
        expect { blog.update_attributes(subdomain: 'soup') }
          .to raise_error(ArgumentError)
      end
    end

    describe '#destroy' do
      before { blog.destroy }

      it 'deletes entire row' do
        expect(subject).to be_nil
      end

      it 'marks record transient' do
        expect(blog).to be_transient
      end

      it 'destroys with specified consistency' do
        blog = Blog.create(subdomain: 'big-data', name: 'Big Data')
        expect_query_with_consistency(anything, :one) do
          blog.destroy(consistency: :one)
        end
      end

      it 'does not destroy records without specified timestamp' do
        blog = Blog.create(subdomain: 'big-data', name: 'Big Data')
        blog.destroy(timestamp: 1.hour.ago)
        expect(cequel[Blog.table_name].where(subdomain: 'big-data').first).to be_truthy
      end
    end
  end

  context 'compound keys' do
    subject do
      cequel[Post.table_name]
        .where(blog_subdomain: 'cassandra', permalink: 'cequel').first
    end

    let!(:post) do
      Post.new do |post|
        post.blog_subdomain = 'cassandra'
        post.permalink = 'cequel'
        post.title = 'Cequel'
        post.body = 'A Ruby ORM for Cassandra 1.2'
      end.tap(&:save)
    end

    describe '#save' do
      context 'on create' do
        it 'saves row to database' do
          expect(subject[:title]).to eq('Cequel')
        end

        it 'marks row persisted' do
          expect(post).to be_persisted
        end

        it 'fails fast if parent keys are missing' do
          expect do
            Post.new do |post|
              post.permalink = 'cequel'
              post.title = 'Cequel'
            end.tap(&:save)
          end.to raise_error(Cequel::Record::MissingKeyError)
        end

        it 'fails fast if row keys are missing' do
          expect do
            Post.new do |post|
              post.blog_subdomain = 'cassandra'
              post.title = 'Cequel'
            end.tap(&:save)
          end.to raise_error(Cequel::Record::MissingKeyError)
        end
      end

      context 'on update' do
        uuid :author_id

        before do
          post.title = 'Cequel 1.0'
          post.author_id = author_id
          post.body = nil
          post.save
        end

        it 'changes existing column value' do
          expect(subject[:title]).to eq('Cequel 1.0')
        end

        it 'adds new column value' do
          expect(subject[:author_id]).to eq(author_id)
        end

        it 'removes old column values' do
          expect(subject[:body]).to be_nil
        end

        it 'does not allow changing parent key values' do
          expect do
            post.blog_subdomain = 'soup'
            post.save
          end.to raise_error(ArgumentError)
        end

        it 'does not allow changing row key values' do
          expect do
            post.permalink = 'soup-recipes'
            post.save
          end.to raise_error(ArgumentError)
        end

        it 'notifies subscribers' do
          expect do
            post.title = 'Cequel 1.0'
            post.save
          end.to notify_name('update.cequel')
        end

      end
    end

    describe '#destroy' do
      before { post.destroy }

      it 'deletes entire row' do
        expect(subject).to be_nil
      end

      it 'marks record transient' do
        expect(post).to be_transient
      end
    end

    describe '#destroy' do
      it 'notifies subscribers' do
        expect { post.destroy }.to notify_name('destroy.cequel')
      end
    end
  end

  # Custom matcher for active support notification
  matcher :notify_name do |expected_name|
    match do |blk|
      notification_recieved = false
      ActiveSupport::Notifications.subscribe expected_name do |*args|
        notification_recieved = true
      end

      blk.call

      notification_recieved
    end

    supports_block_expectations
  end
end
