require File.expand_path('spec_helper', __dir__)
require 'rake'

describe 'migrate' do
  before(:all) do
    Rake.application = Rake::Application.new
    load File.expand_path('../../../lib/cequel/record/tasks.rb', __dir__)
  end

  let(:tmp_root) { Dir.mktmpdir }
  let(:models_path) { File.join(tmp_root, 'app', 'models') }
  let(:suffix) { SecureRandom.hex(4) }

  before do
    FileUtils.mkdir_p(models_path)
    allow(Dir).to receive(:pwd).and_return(tmp_root)
  end

  after { FileUtils.rm_rf(tmp_root) }

  def remove_const(name)
    parts = name.to_s.split('::')
    mod = parts[0..-2].reduce(Object) { |m, p| m.const_get(p) }
    const = parts.last.to_sym
    mod.send(:remove_const, const) if mod.const_defined?(const, false)
  rescue NameError
  end

  context 'with a single Cequel::Record class in a file' do
    let(:file_base) { "migrate_spec_single_#{suffix}" }
    let(:class_name) { file_base.classify }
    let(:table_name) { :"mig_single_#{suffix}" }

    before do
      File.write(File.join(models_path, "#{file_base}.rb"), <<~RUBY)
        class #{class_name}
          include Cequel::Record
          self.table_name = '#{table_name}'
          key :id, :uuid
          column :title, :text
        end
      RUBY
    end

    after do
      remove_const(class_name)
      begin
        cequel.schema.drop_table(table_name)
      rescue StandardError
        nil
      end
    end

    it 'synchronizes the schema' do
      migrate
      table = cequel.schema.read_table(table_name)
      expect(table.partition_key_columns.map(&:name)).to include(:id)
    end

    it 'prints the synchronized class name' do
      expect { migrate }.to output(/Synchronized schema for #{class_name}/).to_stdout
    end
  end

  context 'with multiple Cequel::Record classes in one file' do
    let(:file_base) { "migrate_spec_multi_#{suffix}" }
    let(:class_name_a) { "MigrateSpecMultiA#{suffix.capitalize}" }
    let(:class_name_b) { "MigrateSpecMultiB#{suffix.capitalize}" }
    let(:table_a) { :"mig_multi_a_#{suffix}" }
    let(:table_b) { :"mig_multi_b_#{suffix}" }

    before do
      File.write(File.join(models_path, "#{file_base}.rb"), <<~RUBY)
        class #{class_name_a}
          include Cequel::Record
          self.table_name = '#{table_a}'
          key :id, :uuid
        end

        class #{class_name_b}
          include Cequel::Record
          self.table_name = '#{table_b}'
          key :id, :uuid
        end
      RUBY
    end

    after do
      remove_const(class_name_a)
      remove_const(class_name_b)
      begin
        cequel.schema.drop_table(table_a)
      rescue StandardError
        nil
      end
      begin
        cequel.schema.drop_table(table_b)
      rescue StandardError
        nil
      end
    end

    it 'synchronizes the schema for every class in the file' do
      migrate
      expect(cequel.schema.read_table(table_a)).not_to be_nil
      expect(cequel.schema.read_table(table_b)).not_to be_nil
    end
  end

  context 'with a model in a subdirectory' do
    let(:sub_path) { File.join(models_path, 'admin') }
    let(:file_base) { "migrate_spec_admin_#{suffix}" }
    let(:class_name) { "Admin::#{file_base.classify}" }
    let(:table_name) { :"mig_admin_#{suffix}" }

    before do
      FileUtils.mkdir_p(sub_path)
      File.write(File.join(sub_path, "#{file_base}.rb"), <<~RUBY)
        module Admin
          class #{file_base.classify}
            include Cequel::Record
            self.table_name = '#{table_name}'
            key :id, :uuid
          end
        end
      RUBY
    end

    after do
      remove_const(class_name)
      remove_const('Admin') if defined?(Admin) && Admin.constants.empty?
      begin
        cequel.schema.drop_table(table_name)
      rescue StandardError
        nil
      end
    end

    it 'synchronizes the schema for the namespaced model' do
      migrate
      expect(cequel.schema.read_table(table_name)).not_to be_nil
    end
  end

  context 'with models spread across multiple subdirectories' do
    let(:table_root) { :"mig_root_#{suffix}" }
    let(:table_sub)  { :"mig_sub_#{suffix}" }
    let(:file_base_root) { "migrate_spec_root_#{suffix}" }
    let(:file_base_sub)  { "migrate_spec_sub_#{suffix}" }
    let(:class_root) { file_base_root.classify }
    let(:class_sub)  { "Billing::#{file_base_sub.classify}" }
    let(:sub_path)   { File.join(models_path, 'billing') }

    before do
      FileUtils.mkdir_p(sub_path)
      File.write(File.join(models_path, "#{file_base_root}.rb"), <<~RUBY)
        class #{class_root}
          include Cequel::Record
          self.table_name = '#{table_root}'
          key :id, :uuid
        end
      RUBY
      File.write(File.join(sub_path, "#{file_base_sub}.rb"), <<~RUBY)
        module Billing
          class #{file_base_sub.classify}
            include Cequel::Record
            self.table_name = '#{table_sub}'
            key :id, :uuid
          end
        end
      RUBY
    end

    after do
      remove_const(class_root)
      remove_const(class_sub)
      remove_const('Billing') if defined?(Billing) && Billing.constants.empty?
      begin
        cequel.schema.drop_table(table_root)
      rescue StandardError
        nil
      end
      begin
        cequel.schema.drop_table(table_sub)
      rescue StandardError
        nil
      end
    end

    it 'synchronizes schemas for all models' do
      migrate
      expect(cequel.schema.read_table(table_root)).not_to be_nil
      expect(cequel.schema.read_table(table_sub)).not_to be_nil
    end
  end

  context 'with a non-Cequel class in a file' do
    let(:file_base) { "migrate_spec_plain_#{suffix}" }
    let(:class_name) { file_base.classify }

    before do
      File.write(File.join(models_path, "#{file_base}.rb"), <<~RUBY)
        class #{class_name}
          def hello; 'world'; end
        end
      RUBY
    end

    after { remove_const(class_name) }

    it 'does not raise' do
      expect { migrate }.not_to raise_error
    end

    it 'does not issue any CREATE TABLE statement' do
      expect(cequel.client).not_to receive(:execute).with(/CREATE TABLE/, anything)
      migrate
    end
  end

  context 'when a file does not define a class matching its name' do
    before do
      File.write(File.join(models_path, "migrate_spec_empty_#{suffix}.rb"), '# empty')
    end

    it 'silently rescues NameError' do
      expect { migrate }.not_to raise_error
    end
  end

  context 'when two classes share the same table_name' do
    let(:shared_table) { "mig_shared_#{suffix}" }
    let(:file_base_a) { "migrate_spec_dup_a_#{suffix}" }
    let(:file_base_b) { "migrate_spec_dup_b_#{suffix}" }
    let(:class_name_a) { file_base_a.classify }
    let(:class_name_b) { file_base_b.classify }

    before do
      [file_base_a, file_base_b].each do |base|
        File.write(File.join(models_path, "#{base}.rb"), <<~RUBY)
          class #{base.classify}
            include Cequel::Record
            self.table_name = '#{shared_table}'
            key :id, :uuid
          end
        RUBY
      end
    end

    after do
      remove_const(class_name_a)
      remove_const(class_name_b)
      begin
        cequel.schema.drop_table(shared_table.to_sym)
      rescue StandardError
        nil
      end
    end

    it 'prints "Synchronized schema" exactly once' do
      output = ''
      allow($stdout).to receive(:puts) { |msg| output << msg.to_s }
      migrate
      expect(output.scan('Synchronized schema for').size).to eq(1)
    end
  end
end
