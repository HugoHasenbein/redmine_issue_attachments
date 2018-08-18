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

module IssueAttachmentQueriesHelper
  include ApplicationHelper

  def filters_options_for_select(query)
    ungrouped = []
    grouped = {}
    query.available_filters.map do |field, field_options|
      if [:tree, :relation].include?(field_options[:type]) 
        group = :label_issue
      elsif field =~ /^(.+)\./
        # association filters
        group = "field_#{$1}"
      elsif %w(project_id issue_status).include?(field)
        group = :label_issue
      elsif field_options[:type] == :date_past || field_options[:type] == :date
        group = :label_date
      end
      if group
        (grouped[group] ||= []) << [field_options[:name], field]
      else
        ungrouped << [field_options[:name], field]
      end
    end
    # Don't group dates if there's only one (eg. time entries filters)
    if grouped[:label_date].try(:size) == 1 
      ungrouped << grouped.delete(:label_date).first
    end
    s = options_for_select([[]] + ungrouped)
    if grouped.present?
      localized_grouped = grouped.map {|k,v| [l(k), v]}
      s << grouped_options_for_select(localized_grouped)
    end
    s
  end

  def query_filters_hidden_tags(query)
    tags = ''.html_safe
    query.filters.each do |field, options|
      tags << hidden_field_tag("f[]", field, :id => nil)
      tags << hidden_field_tag("op[#{field}]", options[:operator], :id => nil)
      options[:values].each do |value|
        tags << hidden_field_tag("v[#{field}][]", value, :id => nil)
      end
    end
    tags
  end

  def query_columns_hidden_tags(query)
    tags = ''.html_safe
    query.columns.each do |column|
      tags << hidden_field_tag("c[]", column.name, :id => nil)
    end
    tags
  end

  def query_hidden_tags(query)
    query_filters_hidden_tags(query) + query_columns_hidden_tags(query)
  end

  def available_block_columns_tags(query)
    tags = ''.html_safe
    query.available_block_columns.each do |column|
      tags << content_tag('label', check_box_tag('c[]', column.name.to_s, query.has_column?(column), :id => nil) + " #{column.caption}", :class => 'inline')
    end
    tags
  end

  def available_totalable_columns_tags(query)
    tags = ''.html_safe
    query.available_totalable_columns.each do |column|
      tags << content_tag('label', check_box_tag('t[]', column.name.to_s, query.totalable_columns.include?(column), :id => nil) + " #{column.caption}", :class => 'inline')
    end
    tags << hidden_field_tag('t[]', '')
    tags
  end

  def query_available_inline_columns_options(query)
    (query.available_inline_columns - query.columns).reject(&:frozen?).collect {|column| [column.caption, column.name]}
  end

  def query_selected_inline_columns_options(query)
    (query.inline_columns & query.available_inline_columns).reject(&:frozen?).collect {|column| [column.caption, column.name]}
  end

  def render_query_columns_selection(query, options={})
    tag_name = (options[:name] || 'c') + '[]'
    render :partial => 'queries/columns', :locals => {:query => query, :tag_name => tag_name}
  end

  def render_query_totals(query)
    return unless query.totalable_columns.present?
    totals = query.totalable_columns.map do |column|
      total_tag(column, query.total_for(column))
    end
    content_tag('p', totals.join(" ").html_safe, :class => "query-totals")
  end

  def total_tag(column, value)
    case column.name
    when :filesize
      value = content_tag('span', number_to_human_size(value), :class => 'value')
    else
      value = content_tag('span', format_object(value), :class => 'value')
    end
    label = content_tag('span', "#{column.caption}:")
    content_tag('span', label + " " + value, :class => "total-for-#{column.name.to_s.dasherize}")
  end

  def column_header(column)
    column.sortable ? sort_header_tag(column.name.to_s, :caption => column.caption,
                                                        :default_order => column.default_order) :
                      content_tag('th', h(column.caption))
  end

  def issue_attachment_column_content(column, issue_attachment)
    value = column.value_object(issue_attachment)
    if value.is_a?(Array)
      value.collect {|v| issue_attachment_column_value(column, issue_attachment, v)}.compact.join(', ').html_safe
    else
      issue_attachment_column_value(column, issue_attachment, value)
    end
  end
  
  def issue_attachment_column_value(column, issue_attachment, value)
    case column.name
    when :id
      link_to value.present? ? value : "", issue_attachment_path(issue_attachment)
    when :filename
      link_to_attachment(issue_attachment)
    when :thumbnail
      (Setting.thumbnails_enabled? && issue_attachment.thumbnailable?) ? content_tag(:div, content_tag(:div, thumbnail_tag(issue_attachment)), :class => "thumbnails") : ""
    when :description
      link_to value.present? ? value : "", issue_attachment_path(issue_attachment)
    when :filesize 
      link_to number_to_human_size(value ? value : 0), issue_attachment_path(issue_attachment)
    when :downloads 
      link_to value.present? ? value : "-?-", issue_attachment_path(issue_attachment)
    when :content_type 
      File.extname(issue_attachment.filename)
    when :attachment_category
      attachment_category_tag(issue_attachment.attachment_category, :span)
    else
      format_object(value)
    end
  end

  def csv_content(column, issue)
    value = column.value_object(issue)
    if value.is_a?(Array)
      value.collect {|v| csv_value(column, issue, v)}.compact.join(', ')
    else
      csv_value(column, issue, value)
    end
  end

  def csv_value(column, object, value)
    format_object(value, false) do |value|
      case value.class.name
      when 'Float'
        sprintf("%.2f", value).gsub('.', l(:general_csv_decimal_separator))
      when 'IssueRelation'
        value.to_s(object)
      when 'Issue'
        if object.is_a?(TimeEntry)
          "#{value.tracker} ##{value.id}: #{value.subject}"
        else
          value.id
        end
      else
        value
      end
    end
  end

  def query_to_csv(items, query, options={})
    options ||= {}
    columns = (options[:columns] == 'all' ? query.available_inline_columns : query.inline_columns)
    query.available_block_columns.each do |column|
      if options[column.name].present?
        columns << column
      end
    end

    Redmine::Export::CSV.generate do |csv|
      # csv header fields
      csv << columns.map {|c| c.caption.to_s}
      # csv lines
      items.each do |item|
        csv << columns.map {|c| csv_content(c, item)}
      end
    end
  end

  # Retrieve query from session or build a new query
  def retrieve_issue_attachment_query
    if !params[:query_id].blank?
     cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project
      @query = IssueAttachmentQuery.where(cond).find(params[:query_id])
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:issue_attachment_query] = {:id => @query.id, :project_id => @query.project_id}
      sort_clear
    elsif params[:set_filter] || session[:issue_attachment_query].nil? || session[:issue_attachment_query].nil? || session[:issue_attachment_query][:project_id] != (@project ? @project.id : nil)
     # Give it a name, required to be valid
      @query = IssueAttachmentQuery.new(:name => "_")
      @query.project = @project
      @query.build_from_params(params)
      session[:issue_attachment_query] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names, :totalable_names => @query.totalable_names}
    else
   # retrieve from session
      @query = nil
      @query = IssueAttachmentQuery.find_by_id(session[:issue_attachment_query][:id]) if session[:issue_attachment_query] && session[:issue_attachment_query][:id]
      @query ||= IssueAttachmentQuery.new(:name => "_", :filters => session[:issue_attachment_query][:filters], :group_by => session[:issue_attachment_query][:group_by], :column_names => session[:issue_attachment_query][:column_names], :totalable_names => session[:issue_attachment_query][:totalable_names])
      @query.project = @project
    end
  end

  def retrieve_query_from_session
    if session[:issue_attachment_query]
      if session[:issue_attachment_query][:id]
        @query = IssueAttachmentQuery.find_by_id(session[:issue_attachment_query][:id])
        return unless @query
      else
        @query = IssueAttachmentQuery.new(:name => "_", :filters => session[:issue_attachment_query][:filters], :group_by => session[:issue_attachment_query][:group_by], :column_names => session[:issue_attachment_query][:column_names], :totalable_names => session[:issue_attachment_query][:totalable_names])
      end
      if session[:issue_attachment_query].has_key?(:project_id)
        @query.project_id = session[:issue_attachment_query][:project_id]
      else
        @query.project = @project
      end
      @query
    end
  end

  # Returns the query definition as hidden field tags
  def query_as_hidden_field_tags(query)
    tags = hidden_field_tag("set_filter", "1", :id => nil)

    if query.filters.present?
      query.filters.each do |field, filter|
        tags << hidden_field_tag("f[]", field, :id => nil)
        tags << hidden_field_tag("op[#{field}]", filter[:operator], :id => nil)
        filter[:values].each do |value|
          tags << hidden_field_tag("v[#{field}][]", value, :id => nil)
        end
      end
    else
      tags << hidden_field_tag("f[]", "", :id => nil)
    end
    if query.column_names.present?
      query.column_names.each do |name|
        tags << hidden_field_tag("c[]", name, :id => nil)
      end
    end
    if query.totalable_names.present?
      query.totalable_names.each do |name|
        tags << hidden_field_tag("t[]", name, :id => nil)
      end
    end
    if query.group_by.present?
      tags << hidden_field_tag("group_by", query.group_by, :id => nil)
    end

    tags
  end
end
