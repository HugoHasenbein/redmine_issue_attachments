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

class IssueAttachmentQuery < Query

  self.queried_class = IssueAttachment

  self.available_columns = [
    QueryColumn.new(:id,           :sortable => "#{IssueAttachment.table_name}.id", :default_order => 'desc', :caption => '#', :frozen => true),
    QueryColumn.new(:filename,     :sortable => "#{IssueAttachment.table_name}.filename", :groupable => true),
    QueryColumn.new(:filesize,     :sortable => "#{IssueAttachment.table_name}.filesize", :totalable => true),
    QueryColumn.new(:downloads,    :sortable => "#{IssueAttachment.table_name}.downloads", :totalable => true),
    QueryColumn.new(:description,  :sortable => "#{IssueAttachment.table_name}.description", :groupable => true),
    QueryColumn.new(:content_type, :sortable => "#{IssueAttachment.table_name}.content_type", :groupable => true),
    QueryColumn.new(:author,       :sortable => lambda {User.fields_for_order_statement("authors")}, :groupable => true),
    QueryColumn.new(:created_on,   :sortable => "#{IssueAttachment.table_name}.created_on", :default_order => 'desc'),
    QueryColumn.new(:container,    :sortable => "#{Issue.table_name}.id", :default_order => 'desc', :groupable => true, :caption => :field_issue),

    QueryColumn.new(:project,      :sortable => "#{Project.table_name}.name", :default_order => 'asc', :groupable => "#{Project.table_name}.name", :caption => :field_project),
    QueryColumn.new(:status,       :sortable => "#{IssueStatus.table_name}.position", :default_order => 'asc', :groupable => "#{IssueStatus.table_name}.name", :caption => :field_issue_status),

    QueryColumn.new(:thumbnail,    :caption => :label_thumbnail)

  ]
  
  if IssueAttachment.method_defined?(:attachment_category)
    self.available_columns << 
    QueryColumn.new(:attachment_category,   :sortable => "#{AttachmentCategory.table_name}.position", :default_order => 'asc', :groupable => true) 
  end

  scope :visible, lambda {|*args|
    user = args.shift || User.current
    base = Project.allowed_to_condition(user, :view_issue_attachments, *args)
    scope = joins("LEFT OUTER JOIN #{Project.table_name} ON #{table_name}.project_id = #{Project.table_name}.id").
      where("#{table_name}.project_id IS NULL OR (#{base})")

    if user.admin?
      scope.where("#{table_name}.visibility <> ? OR #{table_name}.user_id = ?", VISIBILITY_PRIVATE, user.id)
    elsif user.memberships.any?
      scope.where("#{table_name}.visibility = ?" +
        " OR (#{table_name}.visibility = ? AND #{table_name}.id IN (" +
          "SELECT DISTINCT q.id FROM #{table_name} q" +
          " INNER JOIN #{table_name_prefix}queries_roles#{table_name_suffix} qr on qr.query_id = q.id" +
          " INNER JOIN #{MemberRole.table_name} mr ON mr.role_id = qr.role_id" +
          " INNER JOIN #{Member.table_name} m ON m.id = mr.member_id AND m.user_id = ?" +
          " WHERE q.project_id IS NULL OR q.project_id = m.project_id))" +
        " OR #{table_name}.user_id = ?",
        VISIBILITY_PUBLIC, VISIBILITY_ROLES, user.id, user.id)
    elsif user.logged?
      scope.where("#{table_name}.visibility = ? OR #{table_name}.user_id = ?", VISIBILITY_PUBLIC, user.id)
    else
      scope.where("#{table_name}.visibility = ?", VISIBILITY_PUBLIC)
    end
  }

  def initialize(attributes=nil, *args)
    super attributes
    self.filters ||= { 'created_on' => {:operator => "w", :values => [""]} }
  end

  # Returns true if the query is visible to +user+ or the current user.
  def visible?(user=User.current)
    return true if user.admin?
    return false unless project.nil? || user.allowed_to?(:view_issue_attachments, project)
    case visibility
    when VISIBILITY_PUBLIC
      true
    when VISIBILITY_ROLES
      if project
        (user.roles_for_project(project) & roles).any?
      else
        Member.where(:user_id => user.id).joins(:roles).where(:member_roles => {:role_id => roles.map(&:id)}).any?
      end
    else
      user == self.user
    end
  end

  def is_private?
    visibility == VISIBILITY_PRIVATE
  end

  def is_public?
    !is_private?
  end

  def initialize_available_filters
    principals = []
    subprojects = []
    versions = []
    categories = []
    issue_custom_fields = []

    if project
      principals += project.principals.visible
      unless project.leaf?
        subprojects = project.descendants.visible.to_a
        principals += Principal.member_of(subprojects).visible
      end
      versions = project.shared_versions.to_a
      categories = project.issue_categories.to_a
      issue_custom_fields = project.all_issue_custom_fields
    else
      if all_projects.any?
        principals += Principal.member_of(all_projects).visible
      end
      versions = Version.visible.where(:sharing => 'system').to_a
      issue_custom_fields = IssueCustomField.where(:is_for_all => true)
    end
    principals.uniq!
    principals.sort!
    principals.reject! {|p| p.is_a?(GroupBuiltin)}
    users = principals.select {|p| p.is_a?(User)}

    if project.nil?
      project_values = []
      if User.current.logged? && User.current.memberships.any?
        project_values << ["<< #{l(:label_my_projects).downcase} >>", "mine"]
      end
      project_values += all_projects_values
      add_available_filter("project_id",
        :type => :list, :values => project_values
      ) unless project_values.empty?
    end

    author_values = []
    author_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
    author_values += users.collect{|s| [s.name, s.id.to_s] }
    add_available_filter("author_id",
      :type => :list, :values => author_values
    ) unless author_values.empty?

    # check if better issue plugin is installed
    if IssueAttachment.method_defined?(:attachment_category)
      add_available_filter "attachment_category_id",
        :type => :list_optional,
        :values => AttachmentCategory.all.collect{|s| [s.name, s.id.to_s] } + ["", ""]
    end

    add_available_filter "filename",            :type => :text
    add_available_filter "filesize",            :type => :float
    add_available_filter "downloads",           :type => :integer
    add_available_filter "description",         :type => :text
    add_available_filter "content_type",        :type => :text
    add_available_filter "created_on",          :type => :date_past
    add_available_filter "issue_attachment_id", :type => :integer, :label => :field_issue_attachment_id
    
    add_available_filter "container_id",        :type => :tree, :label => :field_issue_id
    add_available_filter "issue_subject",       :type => :tree, :label => :field_issue_subject
    add_available_filter "issue_status",
      :type => :list_status, :values => IssueStatus.sorted.collect{|s| [s.name, s.id.to_s] }

    add_available_filter "issue_category_id",
      :type => :list_optional,
      :values => IssueCategory.all.collect{|s| [s.name, s.id.to_s] }


  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = self.class.available_columns.dup
    @available_columns
  end

  def default_columns_names
    @default_columns_names ||= begin
      default_columns = Setting['plugin_redmine_issue_attachments']['list_default_columns'].map(&:to_sym)

      project.present? ? default_columns : [:project] | default_columns
      
    end
  end

  def totalable_names
    options[:totalable_names] || Setting['plugin_redmine_issue_attachments']['list_default_totals'].map(&:to_sym) || []
  end

  def base_scope
    IssueAttachment.visible.joins(:status, :project).where(statement)
  end

  # Returns the attachment count
  def issue_attachment_count
    base_scope.count
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the attachment count by group or nil if query is not grouped
  def issue_attachment_count_by_group
    grouped_query do |scope|
      scope.count
    end
  end

  # Returns sum of all the attachments's filesizes
  def total_for_filesize(scope)
    map_total(scope.sum(:filesize)) {|t| t.to_f.round(2)}
  end

  # Returns sum of all the attachments's filesizes
  def total_for_downloads(scope)
    map_total(scope.sum(:downloads)) {|t| t.to_i}
  end

  # Returns the issue attachment
  # Valid options are :order, :offset, :limit, :include, :conditions
  def issue_attachments(options={})
    order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)

    scope = IssueAttachment.visible.
      joins(:container, :status, :project).
      where(statement).
      includes(([:container, :status, :project] + (options[:include] || []) + (IssueAttachment.method_defined?(:attachment_category) ? [:attachment_category] : []) ).uniq).
      where(options[:conditions]).
      order(order_option).
      joins(joins_for_order_statement(order_option.join(','))).
      limit(options[:limit]).
      offset(options[:offset])
      
    scope = scope.preload(:status)
    scope = scope.preload(:project)
    scope = scope.preload(:attachment_category) if IssueAttachment.method_defined?(:attachment_category)

    if has_column?(:author)
      scope = scope.preload(:author)
    end

    issue_attachments = scope.to_a

    issue_attachments
    
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the issue attachments ids
  def issue_attachment_ids(options={})
    order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)

    IssueAttachment.visible.
      joins(:container, :status, :project).
      where(statement).
      includes(([:container, :status, :project] + (options[:include] || []) + (IssueAttachment.method_defined?(:attachment_category) ? [:attachment_category] : []) ).uniq).
      references(([:container, :status, :project] + (options[:include] || []) + (IssueAttachment.method_defined?(:attachment_category) ? [:attachment_category] : []) ).uniq).
      where(options[:conditions]).
      order(order_option).
      joins(joins_for_order_statement(order_option.join(','))).
      limit(options[:limit]).
      offset(options[:offset]).
      pluck(:id)
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  def sql_for_container_id_field(field, operator, value)
    case operator
    when "="
      ids = value.first.to_s.scan(/\d+/).map(&:to_i)
      if ids.present?
        "#{Issue.table_name}.id IN (#{ids.join(",")})"
      else
        "1=0"
      end
    when "~", "!*", "*"
      sql_for_field("id", operator, value, Issue.table_name, "id")
    end
  end

  def sql_for_project_id_field(field, operator, value)
    case operator
    when "="
      "#{Project.table_name}.id = #{value.first.to_i}"
    when "~"
      "#{Project.table_name}.id IN (#{value.first})"
    when "!*"
      "#{Project.table_name}.id IS NULL"
    when "*"
      "#{Project.table_name}.id IS NOT NULL"
    end
  end

  def sql_for_issue_subject_field(field, operator, value)
    case operator
    when "="
      str = ActiveRecord::Base.sanitize(value.first)
      "#{Issue.table_name}.subject LIKE #{str}"
    when "~"
      str = ActiveRecord::Base.sanitize("%" + value.first  + "%")
      "#{Issue.table_name}.subject LIKE #{str}"
    when "!*"
      "#{Issue.table_name}.subject IS NULL"
    when "*"
      "#{Issue.table_name}.subject IS NOT NULL"
    end
  end

  def sql_for_issue_status_field(field, operator, value)

    case operator
    when "=", "!"
      op = (operator == "=" ? '=' : '!=')
      "#{Issue.table_name}.status_id #{op} #{value.first.to_i}"
    when "*", ""
      op = (operator == "*" ? 'IS NOT' : 'IS')
      "#{Issue.table_name}.status_id #{op} NULL"
    when "o", "c"
      op = (operator == "o" ? 'IN' : 'NOT IN')
      "#{Issue.table_name}.status_id #{op} (SELECT id FROM #{IssueStatus.table_name} WHERE is_closed=#{self.class.connection.quoted_false})"
    end
  end

  def sql_for_issue_category_id_field(field, operator, value)

    case operator
    when "=", "!"
      op = (operator == "=" ? '=' : '!=')
      "#{Issue.table_name}.category_id #{op} #{value.first.to_i}"
    when "*", ""
      op = (operator == "*" ? 'IS NOT' : 'IS')
      "#{Issue.table_name}.category_id #{op} NULL"
    when "o", "c"
      op = (operator == "o" ? 'IN' : 'NOT IN')
      "#{Issue.table_name}.category_id #{op} (SELECT id FROM #{IssueCategory.table_name} WHERE is_closed=#{self.class.connection.quoted_false})"
    end
  end


  def sql_for_issue_attachment_id_field(field, operator, value)
    if operator == "="
      # accepts a comma separated list of ids
      ids = value.first.to_s.scan(/\d+/).map(&:to_i)
      if ids.present?
        "#{IssueAttachment.table_name}.id IN (#{ids.join(",")})"
      else
        "1=0"
      end
    else
      sql_for_field("id", operator, value, IssueAttachment.table_name, "id")
    end
  end

end
