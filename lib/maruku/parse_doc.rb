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

require 'iconv'

class Maruku
	def initialize(s=nil, meta={})
		@node_type = :document
		@doc       = self

		@refs = {}
		@footnotes = {}
		@abbreviations = {}
		@meta = meta
		
		parse_doc(s) if s 
	end
		
	def parse_doc(s)
		# setup initial stack
		@stack = []
		
		meta2 =  parse_email_headers(s)
		data = meta2[:data]
		meta2.delete :data
		
		@meta.merge! meta2
		
		enc = @meta[:encoding]
		@meta.delete :encoding
		if enc && enc.downcase != 'utf-8'
#			puts "Converting from #{enc} to UTF-8."
			converted = Iconv.new('utf-8', enc).iconv(data)
			
#			puts "Data: #{data.inspect}: #{data}"
#			puts "Conv: #{converted.inspect}: #{converted}"
			
			data = converted
		end
		
		lines = Maruku.split_lines(data)
		@children = parse_lines_as_markdown(lines)
		
		if true #markdown_extra? 
			self.search_abbreviations
			self.substitute_markdown_inside_raw_html
		end
		
		toc = create_toc

		# use title if not set
		if not self.meta[:title] and toc.header_element
			title = toc.header_element.to_s
			self.meta[:title]  = title
#			puts "Set document title to #{title}"
		end
		
		# save for later use
		self.toc = toc
		
#		puts self.inspect
	end

	def search_abbreviations
		@abbreviations.each do |abbrev, title|
			reg = Regexp.new(Regexp.escape(abbrev))
			self.replace_each_string do |s|
				if m = reg.match(s)
					e = md_abbr(abbrev.dup)
					e.meta[:title] = title.dup if title
					[m.pre_match, e, m.post_match]
				else
					s
				end
			end
		end
	end
	
	# (PHP Markdown extra) Search for elements that have
	# markdown=1 or markdown=block defined
	def substitute_markdown_inside_raw_html
		self.each_element(:raw_html) do |e|
			doc = e.instance_variable_get :@parsed_html
			if doc # valid html
				# parse block-level markdown elements in these HTML tags
				block_tags = ['div']
				# use xpath to find elements with 'markdown' attribute
				doc.elements.to_a( "//*[attribute::markdown]" ).each do |e|
					# should we parse block-level or span-level?
					parse_blocks = (e.attributes['markdown'] == 'block') || 
					               block_tags.include?(e.name)
					# remove 'markdown' attribute
					e.delete_attribute 'markdown'
					# Select all text elements of e
					e.texts.each do |original_text|
#						puts "parse_blocks = #{parse_blocks} found = #{original_text} "
						s = original_text.to_s.strip # XXX
						el = md_el(:dummy,
						 	parse_blocks ? parse_text_as_markdown(s) :
						                  parse_lines_as_span([s]) )
						el.children_to_html.each do |x|
							e.insert_before(original_text, x)
						end
						e.delete(original_text)
					end
					
				end
			end
		end
	end
	

end