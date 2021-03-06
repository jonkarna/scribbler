require 'spec_helper'

module Scribbler
  describe Base do
    subject { Base }

    before :each do
      Object.send :remove_const, :Rails if defined?(Rails) == 'constant' && Rails.class == Class
      Time.stub :now => "now"
    end

    it "should give me a configurator" do
      subject.config.should == Scribbler::Configurator
    end

    describe "include_in_application" do
      it "should attempt to include to the Rails app" do
        module ::Rails; end
        ::Rails.stub(:application => stub(:class => stub(:parent => stub(:send => true))))
        subject.stub(:config => stub(:application_include => true))
        subject.include_in_application.should be_true
      end

      it "should return nil because it caught the NameError of Rails not existing" do
        subject.stub(:config => stub(:application_include => true))
        subject.include_in_application.should be_nil
      end

      it "should not attempt to include in app if config is false" do
        subject.stub(:config => stub(:application_include => false))
        subject.include_in_application.should be_nil
      end
    end

    describe "configure" do
      it "kicks off the module and sends includes" do
        subject.should_receive(:include_in_application).once
        BaseIncluder.should_receive(:include_includeables).once
        subject.configure do
        end
      end

      it "sets some config variables" do
        subject.configure do
          config.application_include = true
        end
        subject.config.application_include.should be_true
      end
    end

    describe "build with template" do
      let(:some_object) { stub(:id => "no id", :class => stub(:name => "SomeObject")) }
      before :each do
        subject.configure do
          config.application_include = false
        end
      end

      it "calls log, skips templater and still works" do
        subject.send(:build_with_template,
                             :object => some_object,
                             :template => false,
                             :message => "test\n123").should == "test\n123"
      end

      it "calls log and gets message with template wrapper" do
        subject.send(:build_with_template,
                     :template => true,
                     :object => some_object,
                     :message => <<-MSG
        test
        123
        MSG
                           ).should == <<-MSG.strip_heredoc
        -------------------------------------------------
        now
        SomeObject: no id
        test
        123

        MSG
      end

      it "calls log and gets message with custom params" do
        subject.send(:build_with_template,
                     :template => true,
                     :object => some_object,
                     :custom_fields => {:test1 => 1, :test2 => 2},
                     :message => <<-MSG
        test
        123
        MSG
                           ).should == <<-MSG.strip_heredoc
        -------------------------------------------------
        now
        SomeObject: no id
        Test1: 1
        Test2: 2
        test
        123

        MSG
      end
    end

    describe "apply to log" do
      before :each do
        subject.configure do
          config.logs = %w[test_log]
        end
      end

      it "should not work without location" do
        subject.apply_to_log(nil, :message => "...").should be_nil
      end

      it "should not work without message" do
        subject.should_not_receive :test_log_log_location
        subject.apply_to_log(:test_log).should be_nil
      end

      it "should build a template and try to put it in a file" do
        options = { :message => "..." }
        file = mock(:puts => true)
        subject.should_receive(:build_with_template).with options
        subject.should_receive(:log_at).with :test_log
        File.should_receive(:open).and_yield(file)
        subject.apply_to_log :test_log, options
      end

      it "doesn't find a file method" do
        # in case we have bad config data lingering
        subject.stub(:respond_to?).with('test_log_log_location').and_return false
        subject.should_not_receive(:test_log_log_location)
        Rails.should_receive(:root).and_raise(NameError)
        subject.log_at(:test_log).should == "#{subject.config.log_directory}/test_log.log"
      end
    end
  end
end
