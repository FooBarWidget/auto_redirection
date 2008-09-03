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

module ViewHelpers
	# Returns a hidden field tag, which contains information about where the
	# form action should redirect the browser to when it's done.
	#
	# The page to redirect to is retrieved from the redirection information
	# that the current controller action has received. If there is no such
	# information, then this method will return +nil+.
	def pass_redirection_information
		return render_redirection_information(get_redirection_information)
	end
	
	def save_redirection_information
		# TODO: document and test this
		return render_redirection_information(controller.send(:redirection_information_for_current_request))
	end

private
	def get_redirection_information
		return controller.send(:get_redirection_information)
	end
	
	def render_redirection_information(info)
		if info
			RAILS_DEFAULT_LOGGER.info(info.inspect)
			value = h(info.marshal)
			html = %Q{<input type="hidden" name="_redirection_information" value="#{value}"}
			if AutoRedirection.xhtml
				html << " /"
			end
			html << ">"
			if AutoRedirection.debug?
				# Value intentionally not escaped.
				debug_info = info.inspect
				debug_info.gsub!('--', '~~')
				html << "\n<!-- #{debug_info} -->"
			end
			return html
		else
			return nil
		end
	end
end

end # module AutoRedirection
