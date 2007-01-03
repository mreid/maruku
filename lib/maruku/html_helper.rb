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


class Maruku

# This class helps me read and sanitize HTML blocks

# I tried to do this with REXML, but wasn't able to. (suggestions?)

	class HTMLHelper
		include MarukuStrings
		
		Tag = %r{^<(/)?(\w+)\s*([^>]*)>}m
		EverythingElse = %r{^[^<]+}m
		CommentStart = %r{^<!--}x
		CommentEnd = %r{^.*-->}
		TO_SANITIZE = ['img','hr'] 
		
#		attr_accessor :inside_comment
		attr_reader :rest
		
		def initialize 
			@rest = ""
			@tag_stack = []
			@m = nil
			@already = ""
			@inside_comment = false
		end
		
		def eat_this(line)
			@rest = line  + @rest
			things_read = 0
			until @rest.empty?
				if @inside_comment
					if @m = CommentEnd.match(@rest)
						@inside_comment = false
						@already += @m.pre_match + @m.to_s
						@rest = @m.post_match
					elsif @m = EverythingElse.match(@rest)
						@already += @m.pre_match + @m.to_s
						@rest = @m.post_match
					end
				else
					if @m = CommentStart.match(@rest)
						things_read += 1
						@inside_comment = true
						@already += @m.pre_match + @m.to_s
						@rest = @m.post_match
					elsif @m = Tag.match(@rest)
						things_read += 1
						@already += @m.pre_match
						@rest = @m.post_match
					
						is_closing = !!@m[1]
						tag = @m[2]
						attributes = @m[3]
						
						is_single = false
						if attributes =~ /\A(.*)\/\Z/
							attributes = $1
							is_single = true
						end
					
						if TO_SANITIZE.include? tag 
							attributes.strip!
					#		puts "Attributes: #{attributes.inspect}"
							if attributes.size > 0
								@already +=  '<%s %s />' % [tag, attributes]
							else
								@already +=  '<%s />' % [tag]
							end
						elsif is_closing
							@already += @m.to_s
							if @tag_stack.last != tag
								error "Malformed: tag <#{tag}> "+
								      "closes <#{@tag_stack.last}>"
							end
							if @tag_stack.empty?
								error "Malformed: closing tag #{tag.inspect} "+
								      "in empty list"
							end 
							@tag_stack.pop
						elsif not is_single
							@tag_stack.push tag
							@already += @m.to_s
						end
					elsif @m = EverythingElse.match(@rest)
						@already += @m.pre_match + @m.to_s
						@rest = @m.post_match
					else
						error "Malformed HTML: not complete: #{@rest.inspect}"
					end
				end # not inside comment
				
#				puts inspect
#				puts "Read: #{@tag_stack.inspect}"
				break if is_finished? and things_read>0	
			end
		end


		def error(s)
			raise RuntimeError, "Error: #{s} "+ inspect, caller
		end

		def inspect; "HTML READER\n comment=#{@inside_comment} "+
			"match=#{@m.to_s.inspect}\n"+
			"Tag stack = #{@tag_stack.inspect} \n"+
			"Before:\n"+
			add_tabs(@already,1,'|')+"\n"+
			"After:\n"+
			add_tabs(@rest,1,'|')+"\n"
			
		end
		
		
		def stuff_you_read
			@already
		end
		
		def is_finished?
			not @inside_comment and @tag_stack.empty?
		end
	end
end