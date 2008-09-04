require File.dirname(__FILE__) + '/abstract_unit'
require File.dirname(__FILE__) + '/book_store'

class TestMethodsTest < ActionController::IntegrationTest
	include TestHelpers
	include AutoRedirection::Testing
	
	test "scenario with nested redirects" do
		# Visitor is at a book page.
		get "/books/show/1"
		assert_response :ok
		
		# He posts a comment using the form on that page.
		post("/comments/create", { :summary => "hi" })
		# And gets redirected to the login page.
		assert_redirected_to '/login/login_form'
		
		# He loads the login page.
		get('/login/login_form', nil)
		assert_response :ok
		# The login page knows that he came from /comments/create.
		assert_came_from('/comments/create', :summary => "hi")
		
		# He logs in but entered the wrong password.
		post("/login/process_login", :password => 'wrong')
		# So the login page is redisplayed.
		assert_response :ok
		# The login page still knows that he came from /comments/create.
		assert_came_from('/comments/create', :summary => "hi")
		
		# He logs in, this time with the correct password.
		post("/login/process_login", :password => 'secret')
		# The login page redirects him back to /comments/create, with the
		# original parameters.
		assert_redirection_with_method(:post, '/comments/create', :summary => 'hi')
		
		# So the visitor's browser sends a POST request to /comments/create
		# with the correct parameters.
		follow_redirection_with_method!
		# /comments/create redirects the visitor back to /books/show/1 again.
		assert_redirected_to '/books/show/1'
	end
	
	test "get() will record the given path as the referer, and get_with_referer
	      will pass it as the Referer HTTP header" do
		get "/books/show/1"
		get "/books/show/2"
		assert_equal "/books/show/1", @request.headers["Referer"]
	end
	
	test "example for assert_came_from" do
		# User views a book.
		get('/books/show/1')
		
		# On that page, the user clicks on the 'Login' link.
		get('/login/login_form')
		# Assert that the login page knows that he came from /books/show/1
		assert_came_from('/books/show/1')
		
		# The user enters the wrong password and clicks on 'Submit'.
		post('/login/process_login', :username => 'foo', :password => 'wrong')
		# Assert that the login form page told 'process_login' that we came
		# from /books/show/1
		assert_came_from('/books/show/1')
	end
	
	test "example for assert_redirection_with_method" do
		# User posts a comment.
		post('/comments/create', :summary => 'hi')
		# But he isn't logged in, so he's redirected to the login page.
		assert_redirected_to '/login/login_form'
		
		# User loads the login page.
		get('/login/login_form')
		
		# User logs in.
		post('/login/process_login', :password => 'secret')
		# /comments/create with the original parameters. That is, we are
		# dealing with a non-GET redirection.
		assert_redirection_with_method(:post, '/comments/create', :summary => 'hi')
		
		# Follow this instruction, i.e. let us be redirected to
		# /comments/create.
		follow_redirection_with_method!
		
		# NOTE: the first '/comments/create' request didn't have any
		# redirection information. We're redirected back to '/comments/create',
		# and in this case we expect it not to consult the HTTP Referer header.
		assert_equal "Comment 'hi' created!", @response.body
	end
end
