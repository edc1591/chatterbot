require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class StreamingHandler
  attr_accessor :last_object
end

describe "Chatterbot::Streaming" do
  let(:bot) { test_bot }
  let(:user) { fake_user('user', 100) }
  let(:handler) { StreamingHandler.new(test_bot) }
  let(:tweet) { fake_tweet(12345) }

  def apply_to_handler(&block)
    handler.apply block
  end

  describe "authenticated_user" do
    it "should get user from client" do
      expect(bot.client).to receive(:user).and_return('user')
      expect(bot.authenticated_user).to eql('user')
    end
  end

  describe "do_streaming" do

  end

  describe "handle_streaming_object" do
    before(:each) {
      allow(bot.client).to receive(:user).and_return(user)
    }

    describe "Twitter::Tweet" do
      it "works if no handler" do
        bot.handle_streaming_object(tweet, handler)
      end

      context "with handler" do
        before(:each) do
          apply_to_handler { replies { |t| @last_object = t } }
        end

        it "ignores tweets from authenticated user" do
          expect(tweet).to receive(:user).and_return(user)
          bot.handle_streaming_object(tweet, handler)
          expect(handler.last_object).to be_nil
        end
        
        it "passes to handler" do
          bot.handle_streaming_object(tweet, handler)
          expect(handler.last_object).to eql(tweet)
        end

        it "ignores tweets from blocklist" do
          bot.blocklist = ['chatterbot']
          bot.handle_streaming_object(tweet, handler)
          expect(handler.last_object).to be_nil
        end

        it "ignores tweets if skip_me is true" do
          bot.exclude = ['tweet']
          bot.handle_streaming_object(tweet, handler)
          expect(handler.last_object).to be_nil         
        end
      end
    end

    describe "Twitter::Streaming::DeletedTweet" do
      it "works if no handler" do
        obj = Twitter::Streaming::DeletedTweet.new(:id => 1)
        bot.handle_streaming_object(obj, handler)
      end

      it "passes to handler" do
        apply_to_handler { delete { |t| @last_object = t } }
        obj = Twitter::Streaming::DeletedTweet.new(:id => 1)
        bot.handle_streaming_object(obj, handler)
        expect(handler.last_object).to eql(obj)
      end
    end

    describe "Twitter::DirectMessage" do
      it "works if no handler" do
        obj = Twitter::DirectMessage.new(:id => 1)
        bot.handle_streaming_object(obj, handler)
      end

      it "passes to handler" do
        apply_to_handler { direct_message { |t| @last_object = t } }
        obj = Twitter::DirectMessage.new(:id => 1)
        bot.handle_streaming_object(obj, handler)
        expect(handler.last_object).to eql(obj)
      end
    end

    describe "Twitter::Streaming::Event" do
      it "ignores events generated by authenticated user" do
        event = Twitter::Streaming::Event.new(
                                               :event => :follow,
                                               :source => {:id => user.id, :name => 'name', :screen_name => 'name'},
                                               :target => {:id => user.id, :name => 'name', :screen_name => 'name'})

        apply_to_handler { followed { |t| @last_object = t } }
        bot.handle_streaming_object(event, handler)
        expect(handler.last_object).to be_nil
      end

      describe "follow" do
        before(:each) do
          @event = Twitter::Streaming::Event.new(
                                                :event => :follow,
                                                :source => {:id => 12345, :name => 'name', :screen_name => 'name'},
                                                :target => {:id => user.id, :name => 'name', :screen_name => 'name'})

        end

        it "works if no handler" do
          bot.handle_streaming_object(@event, handler)
          expect(handler.last_object).to be_nil
        end

        it "passes to handler" do
          apply_to_handler { followed { |t| @last_object = t } }
          bot.handle_streaming_object(@event, handler)
          expect(handler.last_object.class).to be(Twitter::User)
          expect(handler.last_object.id).to be(12345)
        end
      end

      describe "favorite" do
        before(:each) do
          @event = Twitter::Streaming::Event.new(
                                                 :event => :favorite,
                                                 :source => {:id => 12345, :name => 'name', :screen_name => 'name'},
                                                 :target => {:id => user.id, :name => 'name', :screen_name => 'name'},
                                                 :target_object => {
                                                   :from_user => "chatterbot",
                                                   :id => 56789,
                                                   :text => "I am a tweet!",
                                                   :user => { :id => 1, :screen_name => "chatterbot" }
                                                 })
        end

        it "works if no handler" do
          bot.handle_streaming_object(@event, handler)
          expect(handler.last_object).to be_nil
         end

        it "passes to handler" do
          apply_to_handler { favorited { |_, t| @last_object = t } }
          bot.handle_streaming_object(@event, handler)
          expect(handler.last_object.class).to be(Twitter::Tweet)
          expect(handler.last_object.text).to eq("I am a tweet!")
        end
      end
    end

    describe "Twitter::Streaming::FriendList" do
      it "works if no handler" do
        obj = Twitter::Streaming::FriendList.new
        bot.handle_streaming_object(obj, handler)
      end

      it "passes to handler" do
        apply_to_handler { friends { |t| @last_object = t } }
        obj = Twitter::Streaming::FriendList.new
        bot.handle_streaming_object(obj, handler)
        expect(handler.last_object).to eql(obj)
      end
    end
  end
end
