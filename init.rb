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

require 'redmine'

Redmine::Plugin.register :redmine_issue_attachments do
  name 'Issue Attachments'
  author 'Stephan Wenzel'
  description 'This is a plugin for Redmine to view all issue attachments in one query list'
  version '1.0.4'
  url 'https://github.com/HugoHasenbein/redmine_issue_attachments'
  author_url 'https://github.com/HugoHasenbein/redmine_issue_attachments'

  settings 	:default => {
  			    'list_default_columns' => ['id','content_type','description', 'filename', 'created_on'],
                'list_default_totals' => ['filesize']
             }

  project_module :redmine_issue_attachments do
    
    # set permissions
    permission :view_issue_attachments,
               :issue_attachments => [:index, :issue_attachments_menu, :bulk_pdf, :bulk_zip]

    permission :edit_issue_attachments,
               :issue_attachments => [:bulk_categorize]

    permission :delete_issue_attachments,
               :issue_attachments => [:bulk_delete]

  end

  # this adds the issue attachments menue item to the project menu
  menu :project_menu, 
	   :issue_attachments, # only an item name to control class= and to identify this item
	   { controller: 'issue_attachments', action: 'index' }, 
	   caption: :label_issue_attachments,
	   after:   :issues
end

require 'issue_attachments'



