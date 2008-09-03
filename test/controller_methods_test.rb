require File.dirname(__FILE__) + '/abstract_unit'
require 'uri'

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
