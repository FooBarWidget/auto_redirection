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
module AutoRedirection

module ControllerExtensions
protected
	# Saves the current controller's name, action, HTTP method and parameters
	# as redirection information into the flash. This allows the next controller
	# action to use this information to redirect back to this controller action,
	# with the same HTTP method and parameters.
	#
	# The redirection information that the current controller action has
	# received is also saved, so that nested redirections is possible.
	def save_redirection_information
		flash[:_redirection_information] =
			redirection_information_for_current_request.marshal(true, false)
		logger.debug("Auto-Redirection: saving redirection information " <<
			"for: #{controller_path}/#{action_name} (#{request.method})")
	end
	
	def redirection_parameter_for_current_request
		# TODO: document and test this
		return redirection_information_for_current_request.marshal
	end
	
	# The current request may contain redirection information.
	# If auto-redirection information is given, then this method will redirect
	# the HTTP client to that location (by calling +redirect_to+) and return true.
	# Otherwise, it will return false.
	#
	# Redirection information is obtained from the following sources, in
	# the specified order:
	# 1. The <tt>_redirection_information</tt> request parameter.
	# 2. The <tt>_redirection_information</tt> flash entry.
	# 3. The "Referer" HTTP header.
	def attempt_auto_redirect
		info = get_redirection_information
		if info.nil?
			return false
		end
		
		# The page where we're redirecting to might have redirection information
		# as well. So we save that information to flash[:auto_redirect_to] to
		# allow nested auto-redirections.
		if info.method == :get
			if info.is_a?(UrlRedirectionInformation)
				logger.debug("Auto-Redirection: redirect to URL: #{info.url}")
				redirect_to info.url
			else
				args = info.params.merge(
					:controller => info.controller,
					:action => info.action
				)
				logger.debug("Auto-Redirection: redirecting to: " <<
					"#{info.controller}/#{info.action} (get), " <<
					"parameters: #{info.params.inspect}")
				redirect_to args
			end
		else
			@redirection_information = info
			@form_action = info.params.merge(
				'controller' => info.controller,
				'action'     => info.action
			)
			
			# We want to put nested redirection information a hidden field
			# so that the data can be posted in the POST body instead of
			# the HTTP request query string.
			@nested_redirection_information = @form_action['_redirection_information']
			@form_action.delete('_redirection_information')
			
			logger.debug("Auto-Redirection: redirecting to: " <<
				"#{info.controller}/#{info.action} (#{info.method}), " <<
				"parameters: #{info.params.inspect}")
			render :inline => TEMPLATE_FOR_POST_REDIRECTION, :layout => false
		end
		return true
	end
	
	# Try to redirect the browser by calling +attempt_auto_redirect+. If that
	# method returns false, then the browser will be redirected to a the
	# specified default location instead.
	#
	# Options:
	# - +default+: The default location that this method will redirect the
	#   browser to, if +attempt_auto_redirect+ fails or if the redirection
	#   target matches +exclude+. This may be any value that +redirect_to+
	#   would accept.
	# - +exclude+: A regular expression which specifies a path that
	#   +auto_redirect+ must *not* redirect to. If the place that the browser
	#   is supposed to be redirected to matches this regular expression, then
	#   the browser will be redirected to the default location instead.
	def auto_redirect(options = {})
		# TODO: document that :exclude may also be a Hash, Array or String.
		should_redirect_to_default = false
		if options[:exclude]
			info = get_redirection_information
			if info
				should_redirect_to_default = match_exclusion_list(info,
					options[:exclude])
			end
		end
		if !should_redirect_to_default
			should_redirect_to_default = !attempt_auto_redirect
		end
		if should_redirect_to_default
			redirect_to(options[:default] || root_path)
		end
	end

private
	# Retrieve the redirection information that has been passed to the current
	# controller action. Returns nil if no redirection information has been passed.
	def get_redirection_information
		if !@_redirection_information_given
			if params.has_key?(:_redirection_information)
				info = RedirectionInformation.load(params[:_redirection_information])
			elsif flash.has_key?(:_redirection_information)
				info = RedirectionInformation.load(flash[:_redirection_information], true, false)
			elsif request.headers["Referer"]
				info = UrlRedirectionInformation.new(request.headers["Referer"])
			else
				info = nil
			end
			@_redirection_information_given = true
			@_redirection_information = info
		end
		return @_redirection_information
	end
	
	def redirection_information_for_current_request
		parameters = params
		current_redirection_info = get_redirection_information
		if current_redirection_info
			parameters = params.merge(:_redirection_information =>
				current_redirection_info.marshal)
		else
			parameters = params
		end
		return ControllerRedirectionInformation.new(
			controller_path, action_name, parameters, request.method)
	end
	
	def match_exclusion_list(redirection_info, exclusion_list)
		case exclusion_list
		when Array
			return exclusion_list.any? do |l|
				match_exclusion_list(redirection_info, l)
			end
		when Hash
			args = exclusion_list.merge(:path_only => true)
			return redirection_info.path == url_for(args)
		when String
			return redirection_info.path == exclusion_list
		when Regexp
			return redirection_info.path =~ exclusion_list
		else
			raise ArgumentError
		end
	end
end

end # module AutoRedirections
