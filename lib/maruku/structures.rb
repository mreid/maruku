#   Copyright (C) 2006  Andrea Censi  <andrea (at) rubyforge.org>
#
# This file is part of Maruku.
# 
#   Maruku is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
# 
#   Maruku is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
# 
#   You should have received a copy of the GNU General Public License
#   along with Maruku; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#



class Module
	def safe_attr_accessor(symbol, klass)
		attr_reader symbol
		code = <<-EOF
		def #{symbol}=(val)  
			if not val.kind_of? #{klass}
				s = "Could not assign an object of type \#{val.class} to #{symbol}.\n"
				s += "Tried to assign\n\#{val.inspect}\nto #{symbol} of object\n"
				s += "\#{self.inspect}"
				raise s
			end
			@#{symbol} = val
		end
		
EOF
		module_eval code
  end
end

# I did not want to have a class for each possible element. 
# Instead I opted to have only the class "MDElement"
# that represents eveything in the document (paragraphs, headers, etc).
#
# You can tell what it is by the variable `node_type`. 
#
# In the instance-variable `children` there are the children. These
# can be of class 1) String or 2) MDElement. 
#
# The @doc variable points to the document to which the MDElement
# belongs (which is an instance of Maruku, subclass of MDElement).
#
# Meta data is specified the hash `meta`. Keys are symbols (downcased, with
# spaces substituted by underscores)
#
# For example, if you write in the source document.
# 
#     Title: test document
#     My property: value
#     
#     content content
#
# You can access `value` by writing:
#
#     @doc.meta[:my_property] # => 'value'
#
# from whichever MDElement in the hierarchy.

class MDElement 
	# XXX List not complete
	# Allowed: :document, :paragraph, :ul, :ol, :li, 
	# :li_span, :strong, :emphasis, :link, :email
	safe_attr_accessor :node_type, Symbol
	
	# Children are either Strings or MDElement
	safe_attr_accessor :children, Array
	
	# Hash for metadata
	# contains :id for :link1
	# :li :want_my_paragraph
	#  :header: :level
	# code, inline_code: :raw_code


#	safe_attr_accessor :meta, Hash
	
	# An attribute list, may not be nil
	safe_attr_accessor :al, Array #Maruku::AttributeList

	# These are the processed attributes
	safe_attr_accessor :attributes, Hash
	
	# Reference of the document (which is of class Maruku)
	attr_accessor :doc
	
	def initialize(node_type=:unset, children=[], meta={}, al=AttributeList.new )
		super(); 
		self.children = children
		self.node_type = node_type
		
		@attributes = {}
		
		meta.each do |symbol, value|
			self.instance_eval "
			  def #{symbol}; @#{symbol}; end
			  def #{symbol}=(val); @#{symbol}=val; end"
			self.send "#{symbol}=", value
		end
		
		self.al = al || AttributeList.new

		self.meta_priv = meta
	end
	
	attr_accessor :meta_priv
	
	def ==(o)
		ok = o.kind_of?(MDElement) &&
		(self.node_type == o.node_type) &&
		(self.meta_priv == o.meta_priv) &&
		(self.children == o.children)
		ok
	end
end

# The Maruku class represent the whole document 
# and holds global data.

class Maruku < MDElement
	safe_attr_accessor :refs, Hash
	safe_attr_accessor :footnotes, Hash
	
	# This is an hash. The key might be nil.
	safe_attr_accessor :abbreviations, Hash
	
	# Attribute lists definition
	safe_attr_accessor :ald, Hash
	
	# The order in which footnotes are used. Contains the id.
	safe_attr_accessor :footnotes_order, Array
	
	def initialize(s=nil, meta={})
		super(:document)
		@doc       = self

		self.refs = {}
		self.footnotes = {}
		self.footnotes_order = []
		self.abbreviations = {}
		self.ald = {}
		
		parse_doc(s) if s 
	end

end


