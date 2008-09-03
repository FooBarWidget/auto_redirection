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
require 'uri'

class ApplicationController < ActionController::Base
private
	def logged_in?
		return session[:logged_in]
	end
end

class BooksController < ApplicationController
	def show
		render :inline => %q{
			<% form_tag('/comments/create', :method => 'post') do %>
				<input type="text" name="summary">
				<input type="submit" value="Submit">
			<% end %>
		}
	end
end

class CommentsController < ApplicationController
	def create
		if logged_in?
			if !attempt_auto_redirect
				render :text => "Comment '#{params[:summary]}' created!"
			end
		else
			save_redirection_information
			redirect_to '/login/login_form'
		end
	end
end

class LoginController < ApplicationController
	def login_form
		render :inline => %q{
			<% form_tag('/login/process_login') do %>
				<div class="redirection_info">
					<%= pass_redirection_information %>
				</div>
				<input type="password" name="password">
				<input type="submit" value="Login">
			<% end %>
		}
	end
	
	def process_login
		if params[:password] == "secret"
			session[:logged_in] = true
			auto_redirect
		else
			login_form
		end
	end
end

class NestedRedirectionTest < ActionController::IntegrationTest
	include AutoRedirection
	include TestHelpers
	
	test "scenario with nested redirects" do
		# Visitor is at a book page.
		get "/books/show/1"
		assert_response :ok
		book_redirection_info = UrlRedirectionInformation.new('/books/show/1')
		
		# He posts a comment.
		post("/comments/create", { :summary => "hi" }, :HTTP_REFERER => "/books/show/1")
		# And gets redirected to the login page.
		assert_redirected_to '/login/login_form'
		
		# He loads the login page.
		get('/login/login_form', nil, :HTTP_REFERER => '/login/login_form')
		# There should be redirection information in the form that tells the
		# process_login action that he came from /comments/create.
		assert_response :ok
		value = css_select('.redirection_info input').first['value']
		info = RedirectionInformation.load(value)
		assert_kind_of ControllerRedirectionInformation, info
		assert_equal 'comments', info.controller
		assert_equal 'create', info.action
		assert_equal :post, info.method
		assert_equal({
				"summary" => "hi",
				"controller" => "comments",
				"action" => "create",
				# This happens to include information which tells
				# /comments/create that the visitor came from
				# /books/show/1
				"_redirection_information" => book_redirection_info.marshal
			}, info.params)
		
		# He logs in but entered the wrong password.
		post("/login/process_login", {
				:password => 'wrong',
				:_redirection_information => value
			}, :HTTP_REFERER => "/login/login_form")
		assert_response :ok
		# There should still be redirection information in the form that
		# tells the process_login action that he came from /comments/create.
		assert_response :ok
		value = input_value('.redirection_info input')
		info = RedirectionInformation.load(value)
		assert_kind_of ControllerRedirectionInformation, info
		assert_equal 'comments', info.controller
		assert_equal 'create', info.action
		assert_equal :post, info.method
		assert_equal({
				"summary" => "hi",
				"controller" => "comments",
				"action" => "create",
				# This happens to include information which tells
				# /comments/create that the visitor came from
				# /books/show/1
				"_redirection_information" => book_redirection_info.marshal
			}, info.params)
		
		# He logs in, this time with the correct password.
		post("/login/process_login", {
				:password => 'secret',
				:_redirection_information => value
			}, :HTTP_REFERER => "/login/login_form")
		# The process_login page will render a form for POSTing to
		# /comments/create, with the correct parameters.
		assert_response :ok
		path, query = parse_form_action
		assert_equal '/comments/create', path
		assert_equal({ "summary" => ["hi"] }, query)
		
		# A hidden field contains the original redirection information,
		# which tells /comments/create that the visitor came from
		# /books/show/1.
		value = input_value(".nested_redirection_information input")
		assert_equal book_redirection_info.marshal, value
		
		# The form gets auto-submitted by JavaScript.
		post("/comments/create", {
				:summary => "hi",
				:_redirection_information => value
			},
			:HTTP_REFERER => "/login/process_login")
		
		# /comments/create creates the comment and redirects us back to
		# /books/show/1.
		assert_redirected_to '/books/show/1'
	end
end
