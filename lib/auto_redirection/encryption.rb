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

require 'openssl'
require 'digest/sha2'

module AutoRedirection

# Convenience module for encrypting data. Properties:
# - AES-CBC will be used for encryption.
# - A cryptographic hash will be inserted so that the decryption method
#   can check whether the data has been tampered with.
class Encryption
	SIGNATURE_SIZE = 512 / 8    # Size of a binary SHA-512 hash.

	# Encrypts the given data, which may be an arbitrary string.
	#
	# If +ascii7+ is true, then the encrypted data will be returned, in a
	# format that's ASCII-7 compliant and URL-friendly (i.e. doesn't
	# need to be URL-escaped).
	#
	# Otherwise, the encrypted data in binary format will be returned.
	def self.encrypt(data, ascii7 = true)
		signature = Digest::SHA512.digest(data)
		encrypted_data = aes(:encrypt, AutoRedirection.encryption_key, signature << data)
		if ascii7
			return encode_base64_url(encrypted_data)
		else
			return encrypted_data
		end
	end

	# Decrypt the given data, which was encrypted by the +encrypt+ method.
	#
	# The +ascii7+ parameter specifies whether +encrypt+ was called with
	# its +ascii7+ argument set to true.
	#
	# If +data+ is nil, then nil will be returned. Otherwise, it must
	# be a String.
	#
	# Returns the decrypted data as a String, or nil if the data has been
	# corrupted or tampered with.
	def self.decrypt(data, ascii7 = true)
		if data.nil?
			return nil
		end
		if ascii7
			data = decode_base64_url(data)
			if data.nil? || data.empty?
				return nil
			end
		end
		decrypted_data = aes(:decrypt, AutoRedirection.encryption_key, data)
		if decrypted_data.size < SIGNATURE_SIZE
			return nil
		end
		signature = decrypted_data.slice!(0, SIGNATURE_SIZE)
		if Digest::SHA512.digest(decrypted_data) != signature
			return nil
		end
		return decrypted_data
	rescue OpenSSL::CipherError
		return nil
	end

	# Encode the given data with "modified Base64 for URL". See
	# http://tinyurl.com/5tcnra for details.
	def self.encode_base64_url(data)
		data = [data].pack("m")
		data.gsub!('+', '-')
		data.gsub!('/', '_')
		data.gsub!(/(=*\n\Z|\n*)/, '')
		return data
	end
	
	# Encode the given data, which is in "modified Base64 for URL" format.
	# This method never raises an exception, but will return invalid data
	# if +data+ is not in a valid format.
	def self.decode_base64_url(data)
		data = data.gsub('-', '+')
		data.gsub!('_', '/')
		padding_size = 4 - (data.size % 4)
		data << ('=' * padding_size) << "\n"
		return data.unpack("m*").first
	end

private
	def self.aes(m, k, t)
		cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc').send(m)
		cipher.key = Digest::SHA256.digest(k)
		return cipher.update(t) << cipher.final
	end
end

end # AutoRedirection
