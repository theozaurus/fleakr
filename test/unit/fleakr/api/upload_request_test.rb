require File.dirname(__FILE__) + '/../../../test_helper'

module Fleakr::Api
  class UploadRequestTest < Test::Unit::TestCase

    describe "An instance of the UploadRequest class" do

      before do
        @secret = 'sekrit'
        Fleakr.stubs(:shared_secret).with().returns(@secret)
      end
      
      it "should have a collection of upload_options" do
        request = UploadRequest.new('foo', :create, {:title => 'foo', :tags => %w(a b)})
        
        option_1, option_2 = [stub(:to_hash => {:one => 'value_1'}), stub(:to_hash => {:two => 'value_2'})]
        
        Option.expects(:for).with(:title, 'foo').returns(option_1)
        Option.expects(:for).with(:tags, %w(a b)).returns(option_2)
        
        request.upload_options.should == {:one => 'value_1', :two => 'value_2'}
      end
      
      it "should create a file parameter on initialization" do
        filename = '/path/to/image.jpg'

        parameter = stub()
        FileParameter.expects(:new).with('photo', filename).returns(parameter)

        parameter_list = mock() {|m| m.expects(:<<).with(parameter) }
        ParameterList.expects(:new).with({}).returns(parameter_list)

        UploadRequest.new(filename)
      end
      
      it "should allow setting options on initialization" do
        option = stub {|s| s.stubs(:to_hash).with().returns({:title => 'foo'})}
        Option.expects(:for).with(:title, 'foo').returns(option)
        
        ParameterList.expects(:new).with({:title => 'foo'}).returns(stub(:<<))
        
        UploadRequest.new('filename', :create, {:title => 'foo'})
      end

      context "after initialization" do

        before { ParameterList.stubs(:new).returns(stub(:<< => nil)) }

        it "should default the type to :create" do
          request = UploadRequest.new('file')
          request.type.should == :create
        end
        
        it "should allow setting the type to :update" do
          request = UploadRequest.new('file', :update)
          request.type.should == :update
        end

        it "should know the endpoint_uri" do
          request = UploadRequest.new('filename')
          request.__send__(:endpoint_uri).should == URI.parse('http://api.flickr.com/services/upload/')
        end
        
        it "should know the endpoint_uri for an :update request" do
          request = UploadRequest.new('filename', :update)
          request.__send__(:endpoint_uri).should == URI.parse('http://api.flickr.com/services/replace/')
        end
        
        it "should only parse the endpoint URI once" do
          request = UploadRequest.new('filename')
          URI.expects(:parse).with(kind_of(String)).once.returns('uri')
          
          2.times { request.__send__(:endpoint_uri) }
        end

        it "should have a collection of required headers" do
          form_data = 'data'

          request = UploadRequest.new('filename')
          request.parameters.stubs(:boundary).with().returns('bound')
          request.parameters.stubs(:to_form).with().returns(form_data)

          expected = {
            'Content-Type' => 'multipart/form-data; boundary=bound'
          }

          request.headers.should == expected
        end

        it "should be able to send a POST request to the API service" do
          request = UploadRequest.new('filename')
          
          uri = stub do |s|
            s.stubs(:host).with().returns('host')
            s.stubs(:path).with().returns('path')
            s.stubs(:port).with().returns(80)
          end
          
          request.stubs(:endpoint_uri).with().returns(uri)
          
          request.stubs(:headers).with().returns('header' => 'value')
          request.parameters.stubs(:to_form).with().returns('form')

          http = mock {|m| m.expects(:post).with('path', 'form', {'header' => 'value'}) }

          Net::HTTP.expects(:start).with('host', 80).yields(http).returns(stub(:body))
          
          request.send
        end
        
        it "should get back a response from a POST operation" do
          response = stub()
          
          Net::HTTP.expects(:start).with(kind_of(String), kind_of(Fixnum)).returns(stub(:body => '<xml>'))
          Response.expects(:new).with('<xml>').returns(response)
          
          request = UploadRequest.new('filename')
          request.send.should == response
        end
        
        it "should be able to make a full request and response cycle" do
          filename = 'filename'
          response = stub(:error? => false)
          
          UploadRequest.expects(:new).with(filename, :create, {}).returns(stub(:send => response))
          UploadRequest.with_response!(filename).should == response
        end
        
        it "should raise an exception when the full request / response cycle has errors" do
          filename = 'filename'
          response = stub(:error? => true, :error => stub(:code => '1', :message => 'User not found'))
          
          UploadRequest.expects(:new).with(filename, :create, {}).returns(stub(:send => response))
          
          lambda do
            UploadRequest.with_response!(filename)
          end.should raise_error(Fleakr::ApiError)
        end
        
      end

    end

  end
end