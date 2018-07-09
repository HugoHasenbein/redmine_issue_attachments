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

class IssueAttachment < Attachment

  # all stuff below does not affect attachments class
  self.table_name = "attachments"
  
  # disable STI (single table inheritance) to allow columns named 
  # "type" to be ignored; else 'scope' below would include 
  # attachments.type == 'IssueAttachment'
  self.inheritance_column = :_type_disabled  
  
  belongs_to 	  :container, :class_name => 'Issue'
  has_one   	  :project, :through => :container, :class_name => 'Project'
  has_one   	  :status,  :through => :container, :class_name => 'IssueStatus'
  
  scope :visible, lambda {|*args|
	where(:container_type => "Issue").
     joins(:project).
	 where(Project.allowed_to_condition(args.shift || User.current, :view_issue_attachments, *args))
   }
   
  def status
    super.name
  end #end 

  def project
    super.name
  end #end 
   
end #class
