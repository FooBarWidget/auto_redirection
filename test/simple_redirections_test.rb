# Copyright (c) 2008 Phusion
# http://www.phusion.nl/
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require File.dirname(__FILE__) + '/abstract_unit'

class TestController < ActionController::Base
	def action_attempt_auto_redirect
		if !attempt_auto_redirect
			render :text => 'false'
		end
	end
	
	def action_save_redirection_information
		save_redirection_information
		render :nothing => true
	end
	
	def action_pass_redirection_information
		render :inline => '<%= pass_redirection_information %>'
	end
end

class UsersController < ActionController::Base
end

class SimpleRedirectionTest < ActionController::TestCase
	include AutoRedirection
	include TestHelpers
	tests TestController
	
	test "attempt_auto_redirect returns false if there's no redirection information" do
		get :action_attempt_auto_redirect
		assert_equal 'false', @response.body
	end
	
	
	##### URL GET redirections #####
	
	test "attempt_auto_redirect redirects to the URL given by the Referer HTTP header" do
		@controller.request.headers["Referer"] = '/foo'
		get :action_attempt_auto_redirect
		assert_redirected_to '/foo'
	end
	
	test "attempt_auto_redirect redirects to the URL given by the
	      _redirection_information HTTP parameter" do
		info = UrlRedirectionInformation.new('http://www.google.com')
		get(:action_attempt_auto_redirect, :_redirection_information => info.marshal)
		assert_redirected_to 'http://www.google.com'
	end
	
	test "attempt_auto_redirect redirects to the URL given by the
	      _redirection_information flash" do
		info = UrlRedirectionInformation.new('http://www.google.com')
		get(:action_attempt_auto_redirect, nil, nil,
			:_redirection_information => info.marshal(true, false))
		assert_redirected_to 'http://www.google.com'
	end
	
	
	##### Non-URL (controller information) GET redirections #####
	
	test "attempt_auto_redirect redirects to the non-URL location given by the
	      _redirection_information HTTP parameter" do
		info = ControllerRedirectionInformation.new('users', 'show')
		get(:action_attempt_auto_redirect, :_redirection_information => info.marshal)
		assert_redirected_to '/users/show'
	end
	
	test "attempt_auto_redirect redirects to the non-URL location given by the
	      _redirection_information HTTP flash" do
		info = ControllerRedirectionInformation.new('users', 'show')
		get(:action_attempt_auto_redirect, nil, nil,
			:_redirection_information => info.marshal(true, false))
		assert_redirected_to '/users/show'
	end
	
	
	##### Non-GET redirections #####
	
	test "attempt_auto_redirect renders a page with a form when the redirection
	      information does not pertain a GET request" do
		info = ControllerRedirectionInformation.new('users', 'create', nil, :post)
		get(:action_attempt_auto_redirect, :_redirection_information => info.marshal)
		assert_response :ok
		assert_select 'form'
	end
	
	test "the form that attempt_auto_redirect renders contains the correct form action" do
		info = ControllerRedirectionInformation.new('users', 'create',
			{ :hello => "world", :foo => "bar" }, :post)
		get(:action_attempt_auto_redirect, :_redirection_information => info.marshal)
		path, query = parse_form_action
		assert_equal '/users/create', path
		assert_equal({ "hello" => ["world"], "foo" => ["bar"] }, query)
	end
	
	test "action_save_redirection_information saves the current request details into the flash" do
		post(:action_save_redirection_information, :hello => "world", :foo => ["bar", "baz"])
		info = RedirectionInformation.load(@response.flash[:_redirection_information], true, false)
		assert_kind_of ControllerRedirectionInformation, info
		assert_equal :post, info.method
		assert_equal({
				'controller' => @controller.controller_path,
				'action' => "action_save_redirection_information",
				'hello' => "world",
				'foo' => ["bar", "baz"]
			}, info.params)
	end
	
	
	##### View helpers #####
	
	test "the pass_redirection_information view helper returns nil if there's no redirection information" do
		get(:action_pass_redirection_information)
		assert_equal [], css_select("input")
	end
	
	test "the pass_redirection_information view helper saves the passed redirection information" do
		info = ControllerRedirectionInformation.new('users', 'create',
			{ :hello => "world", :foo => "bar" }, :post)
		get(:action_pass_redirection_information, :_redirection_information => info.marshal)
		info2 = RedirectionInformation.load(input_value)
		assert_equal info, info2
	end
	
	test "the pass_redirection_information view helper saves the HTTP referer" do
		@controller.request.headers["Referer"] = '/foo'
		get(:action_pass_redirection_information)
		info = RedirectionInformation.load(input_value)
		assert_kind_of UrlRedirectionInformation, info
		assert_equal '/foo', info.url
	end
end
