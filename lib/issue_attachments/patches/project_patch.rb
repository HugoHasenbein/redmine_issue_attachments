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

module IssueAttachments
  module Patches
    module ProjectPatch
      def self.included(base)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable

          has_many :issue_attachments, :through => :issues
          
        end
      end

      module InstanceMethods
                      
      end
      
    end
  end
end


unless Project.included_modules.include?(IssueAttachments::Patches::ProjectPatch)
    Project.send(:include, IssueAttachments::Patches::ProjectPatch)
end
