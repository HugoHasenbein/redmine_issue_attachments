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

RedmineApp::Application.routes.draw do

  # routes for issue attachments queries in the global menu
  resources :issue_attachment_queries, :except => [:show]

  # routes for issue attachment queries in the project menu
  resources :projects do
      resources :issue_attachment_queries, :only => [:new, :create]
  end
  
  # routes for the index view in the projects menu
  match "/projects/:id/issue_attachments" => "issue_attachments#index", :as => "project_issue_attachments", :via => [:get]

  # issue attachments routes all requests but 'index' to attachments
  resources :issue_attachments do 
    collection do
      post 'bulk_pdf'
      post 'bulk_zip'
      post 'bulk_delete'
      post 'bulk_categorize'
    end
  end

  # routes for the issue attachments context menu
  match "/issue_attachments_menu" => "issue_attachments#issue_attachments_menu", :as => "issue_attachments_menu",     :via => [:get]

end
