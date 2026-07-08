require File.expand_path('../spec_helper', __dir__)

describe Cequel::Schema::TableUpdater do
  let(:table_name) { :"posts_#{SecureRandom.hex(4)}" }
  let(:table) { cequel.schema.read_table(table_name) }

  before do
    cequel.schema.create_table(table_name) do
      key :blog_subdomain, :text
      key :permalink, :text
      column :title, :ascii
      column :body, :text
    end
  end

  after { cequel.schema.drop_table(table_name) }

  describe '#add_column' do
    before do
      cequel.schema.alter_table(table_name) do
        add_column :published_at, :timestamp
      end
    end

    it 'adds the column with the given type' do
      expect(table.data_column(:published_at).type).to eq(Cequel::Type[:timestamp])
    end
  end

  describe '#add_list' do
    before do
      cequel.schema.alter_table(table_name) do
        add_list :author_names, :text
      end
    end

    it 'adds the list' do
      expect(table.data_column(:author_names)).to be_a(Cequel::Schema::List)
    end

    it 'sets the given type' do
      expect(table.data_column(:author_names).type).to eq(Cequel::Type[:text])
    end
  end

  describe '#add_set' do
    before do
      cequel.schema.alter_table(table_name) do
        add_set :author_names, :text
      end
    end

    it 'adds the list' do
      expect(table.data_column(:author_names)).to be_a(Cequel::Schema::Set)
    end

    it 'sets the given type' do
      expect(table.data_column(:author_names).type).to eq(Cequel::Type[:text])
    end
  end

  describe '#add_map' do
    before do
      cequel.schema.alter_table(table_name) do
        add_map :trackbacks, :timestamp, :ascii
      end
    end

    it 'adds the list' do
      expect(table.data_column(:trackbacks)).to be_a(Cequel::Schema::Map)
    end

    it 'sets the key type' do
      expect(table.data_column(:trackbacks).key_type)
        .to eq(Cequel::Type[:timestamp])
    end

    it 'sets the value type' do
      expect(table.data_column(:trackbacks).value_type)
        .to eq(Cequel::Type[:ascii])
    end
  end

  describe '#rename_column' do
    before do
      cequel.schema.alter_table(table_name) do
        rename_column :permalink, :slug
      end
    end

    it 'changes the name' do
      expect(table.clustering_column(:slug)).to be_truthy
      expect(table.clustering_column(:permalink)).to be_nil
    end
  end

  describe '#change_properties' do
    before do
      cequel.schema.alter_table(table_name) do
        change_properties comment: 'Test Comment'
      end
    end

    it 'changes properties' do
      expect(table.properties[:comment].value).to eq('Test Comment')
    end
  end

  describe '#drop_index' do
    context 'index exists' do
      before do
        tab_name = table_name
        cequel.schema.alter_table(table_name) do
          create_index :title
          drop_index :"#{tab_name}_title_idx"
        end
      end

      it 'drops the index' do
        expect(table.data_column(:title)).not_to be_indexed
      end
    end

    context 'index does not exist' do
      before do
        tab_name = table_name
        cequel.schema.alter_table(table_name) do
          drop_index :"#{tab_name}_title_idx"
        end
      end

      it 'nops on non existent index' do
        expect(table.data_column(:title)).not_to be_indexed
      end
    end
  end

  describe '#add_index' do
    before do
      cequel.schema.alter_table(table_name) do
        create_index :title
      end
    end

    it 'adds the index' do
      expect(table.data_column(:title)).to be_indexed
    end
  end

  describe '#drop_column' do
    before do
      cequel.schema.alter_table(table_name) do
        drop_column :body
      end
    end

    it 'removes the column' do
      expect(table.data_column(:body)).to be_nil
    end
  end
end
