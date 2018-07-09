# encoding: utf-8
#
# Redmine plugin to view all issue attachments in one query list
#
# Copyright © 2018 Stephan Wenzel <stephan.wenzel@drwpatent.de>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

module IssueAttachmentsHelper

  #------------------------------------------------------------------------------------- #
  #------------------------------------------------------------------------------------- #
  # queries
  #------------------------------------------------------------------------------------- #

  #------------------------------------------------------------------------------------- #
  def issue_attachment_list(issue_attachments, &block)
   ancestors = []
   issue_attachments.each do |issue_attachment|
	 yield issue_attachment, ancestors.size
	 ancestors << issue_attachment
   end
  end

  #------------------------------------------------------------------------------------- #
  def grouped_issue_attachment_list(issue_attachments, query, issue_attachment_count_by_group, &block)
	previous_group, first = false, true
	totals_by_group = query.totalable_columns.inject({}) do |h, column|
	  h[column] = query.total_by_group_for(column)
	  h
	end
	issue_attachment_list(issue_attachments) do |issue_attachment, level|
	  group_name = group_count = nil
	  if query.grouped?
		group = query.group_by_column.value(issue_attachment)
		#db_group = query.group_by_column.database_value(issue_attachments)
		if issue_attachment.has_attribute?( query.group_by_column.name )
		  db_group = issue_attachment.read_attribute( query.group_by_column.name.to_sym )
		else
		  #if column does not exist, then there must be a function
		  #the send method is identical to the query.group_by_column.value funtion
		  db_group = issue_attachment.send query.group_by_column.name
		end

		if first || group != previous_group
		  if group.blank? && group != false
			group_name = "(#{l(:label_blank_value)})"
		  else
		    # handle special case content_type
		    if query.group_by_column.name.to_s == "content_type"
		      group_name = File.extname(issue_attachment.filename)
		    else
			  group_name = format_object(group)
			end
		  end
		  group_name ||= ""
		  group_count = issue_attachment_count_by_group[db_group]
		  group_totals = totals_by_group.map {|column, t| total_tag(column, t[db_group] || 0)}.join(" ").html_safe
		end
	  end
	  yield issue_attachment, level, group_name, group_count, group_totals
	  previous_group, first = group, false
	end
  end

  #------------------------------------------------------------------------------------- #
  def sidebar_issue_attachment_queries
	unless @sidebar_issue_attachment_queries
	  @sidebar_issue_attachment_queries = IssueAttachmentQuery.visible.
		order("#{Query.table_name}.name ASC").
		# Project specific queries and global queries
		where(@project.nil? ? ["project_id IS NULL"] : ["project_id IS NULL OR project_id = ?", @project.id]).
		to_a
	end
	@sidebar_issue_attachment_queries
  end

  #------------------------------------------------------------------------------------- #
  def issue_attachment_query_links(title, queries)
	return '' if queries.empty?
	# links to #index on issues/show
	url_params = controller_name == 'issue_attachments' ? {:controller => 'issue_attachments', :action => 'index', :project_id => @project} : params

	content_tag('h3', title) + "\n" +
	  content_tag('ul',
		queries.collect {|query|
			css = 'query'
			css << ' selected' if query == @query
			content_tag('li', link_to(query.name, url_params.merge(:query_id => query), :class => css))
		  }.join("\n").html_safe,
		:class => 'queries'
	  ) + "\n"
  end

  #------------------------------------------------------------------------------------- #
  def render_sidebar_issue_attachment_queries
	out = ''.html_safe
	out << issue_attachment_query_links(l(:label_my_queries), sidebar_issue_attachment_queries.select(&:is_private?))
	out << issue_attachment_query_links(l(:label_query_plural), sidebar_issue_attachment_queries.reject(&:is_private?))
	out
  end

  #------------------------------------------------------------------------------------- #
  #------------------------------------------------------------------------------------- #
  # context menu
  #------------------------------------------------------------------------------------- #

  # Generates a url to an attachment.
  # Options:
  # * :download - Force download (default: false)
  def context_url_to_attachment(attachment, options={})
    route_method = options.delete(:download) ? :download_named_attachment_url : :named_attachment_url
    options[:only_path] = true unless options.key?(:only_path)
    url = send(route_method, attachment, attachment.filename, options)
    url
  end
		
end #module