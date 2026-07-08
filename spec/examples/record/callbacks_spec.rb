require File.expand_path('spec_helper', __dir__)

describe Cequel::Record::Callbacks do
  model :Post do
    key :permalink, :text
    column :title, :text

    def self.track_callbacks(*events)
      events.each do |event|
        %w[before after].each do |position|
          callback_name = :"#{position}_#{event}"
          __send__(callback_name) do |post|
            post.executed_callbacks << callback_name
          end
        end
      end
    end

    track_callbacks :save, :create, :update, :destroy

    def executed_callbacks
      @executed_callbacks ||= []
    end

  end

  model :Comment do
    belongs_to :post
    key :id, :timeuuid, auto: true
    column :body, :text

    before_save :create_post
    after_save :run_instance_after_save

    attr_writer :instance_after_save

    private

    def create_post
      post = Post.create!(permalink: 'autopost', title: 'Auto Post')
      self.post = post
    end

    def run_instance_after_save
      @instance_after_save.call
    end
  end

  let(:new_post) do
    Post.new do |post|
      post.permalink = 'new-post'
      post.title = 'New Post'
    end
  end

  let!(:existing_post) do
    Post.new do |post|
      post.permalink = 'existing-post'
      post.title = 'Existing Post'
    end.save!
    Post.find('existing-post').tap do |post|
      post.title = 'An Existing Post'
    end
  end

  context 'on create' do
    subject { new_post.executed_callbacks }

    before { new_post.save! }

    it { is_expected.to include(:before_save) }
    it { is_expected.to include(:after_save) }
    it { is_expected.to include(:before_create) }
    it { is_expected.to include(:after_create) }
    it { is_expected.not_to include(:before_update) }
    it { is_expected.not_to include(:after_update) }
    it { is_expected.not_to include(:before_destroy) }
    it { is_expected.not_to include(:after_destroy) }
  end

  context 'on update' do
    subject { existing_post.executed_callbacks }

    before { existing_post.save! }

    it { is_expected.to include(:before_save) }
    it { is_expected.to include(:after_save) }
    it { is_expected.not_to include(:before_create) }
    it { is_expected.not_to include(:after_create) }
    it { is_expected.to include(:before_update) }
    it { is_expected.to include(:after_update) }
    it { is_expected.not_to include(:before_destroy) }
    it { is_expected.not_to include(:after_destroy) }
  end

  context 'on destroy' do
    subject { existing_post.executed_callbacks }

    before { existing_post.destroy }

    it { is_expected.not_to include(:before_save) }
    it { is_expected.not_to include(:after_save) }
    it { is_expected.not_to include(:before_create) }
    it { is_expected.not_to include(:after_create) }
    it { is_expected.not_to include(:before_update) }
    it { is_expected.not_to include(:after_update) }
    it { is_expected.to include(:before_destroy) }
    it { is_expected.to include(:after_destroy) }
  end

  describe 'atomic writes' do
    it 'runs callbacks in a logged batch' do
      comment = Comment.new(body: 'Great web site!')
      comment.instance_after_save =
        lambda { 
          expect { Post.find('autopost') }
            .to raise_error(Cequel::Record::RecordNotFound)
        }
      comment.save!
      expect(Post.find('autopost').title).to eq('Auto Post')
    end
  end
end
