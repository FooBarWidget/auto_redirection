require File.dirname(__FILE__) + '/abstract_unit'
require File.dirname(__FILE__) + '/book_store'

class NestedRedirectionTest < ActionController::IntegrationTest
	include AutoRedirection
	include TestHelpers
	
	test "scenario with nested redirects" do
		# Visitor is at a book page.
		get "/books/show/1"
		assert_response :ok
		book_redirection_info = UrlRedirectionInformation.new('/books/show/1')
		
		# He posts a comment using the form on that page.
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
