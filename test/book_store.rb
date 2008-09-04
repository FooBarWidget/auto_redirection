require File.dirname(__FILE__) + '/abstract_unit'

class ApplicationController < ActionController::Base
	def root_path
		return '/books/show/123'
	end
	
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
