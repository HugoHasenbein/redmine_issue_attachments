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

require 'combine_pdf'
require 'zip'

class IssueAttachmentsController < AttachmentsController


  before_action :find_optional_project,  :only => [:index]
  before_action :find_issue_attachments, :only => [:issue_attachments_menu, :bulk_pdf, :bulk_zip, :bulk_delete, :bulk_categorize]
  before_action :authorize

  helper :issue_attachment_queries
  include IssueAttachmentQueriesHelper
  helper :sort
  include SortHelper
  helper :issue_attachment_routes
  include IssueAttachmentRoutesHelper
  helper :context_menus
  include ContextMenusHelper

  # ------------------------------------------------------------------------------#
  def index
  
    retrieve_issue_attachment_query
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      @limit = per_page_option

      @issue_attachment_count = @query.issue_attachment_count
      @issue_attachment_pages = Redmine::Pagination::Paginator.new @issue_attachment_count, @limit, params['page']
      @offset ||= @issue_attachment_pages.offset
      @issue_attachments = @query.issue_attachments(:include => [],
                                                    :order => sort_clause,
                                                    :offset => @offset,
                                                    :limit => @limit)
      @issue_attachment_count_by_group = @query.issue_attachment_count_by_group

      respond_to do |format|
        format.html { render :template => 'issue_attachments/index', :layout => !request.xhr? }
      end
    else
      respond_to do |format|
        format.html { render(:template => 'issue_attachments/index', :layout => !request.xhr?) }
      end
    end
    
  rescue ActiveRecord::RecordNotFound
    render_404
  end #def

  # ------------------------------------------------------------------------------#
  def bulk_pdf
    if (@issue_attachments.size == 1)
      @issue_attachment = @issue_attachments.first
    end
    
    begin
	  # create empty pdf
	  bulk_pdf = CombinePDF.new

	  num_pages = 0
	  len = params[:ids].length
	  params[:ids].each_with_index do |id, index|
		# select issue_attachment in exact order as selected in index
		issue_attachment = @issue_attachments.select { |ia| ia.id == id.to_i }.first
	
		# append current pdf
		tmppdf = CombinePDF.load(issue_attachment.diskfile) # load pdf 
		bulk_pdf << tmppdf # append pdf
		num_pages += tmppdf.pages.length # account page numbers

		# add empty page to make sure each new pdf starts on right page
		if !num_pages.even? && index < (len-1) && params[:double_sided_printing].present?
		 bulk_pdf << CombinePDF.create_page(tmppdf.pages.last.mediabox)
		 num_pages += 1
		end
	  
	  end #each
	  
      send_data bulk_pdf.to_pdf, 
      			:filename => "combined.pdf", 
      			:type => "application/pdf",
			    :x_sendfile => true
      			
      return
      
    rescue Exception => e
      flash[:warning] = e.message
      redirect_to :back
    end 
    
  end #def
  
  # ------------------------------------------------------------------------------#
  def bulk_zip
    if (@issue_attachments.size == 1)
      @issue_attachment = @issue_attachments.first
    end
    
    # create empty pdf
    tmp_zipfile = Tempfile.new('zipfile')

    len = params[:ids].length
    num_digits = Math.log10(len).to_i + 2
    
    Zip::File.open(tmp_zipfile.path, Zip::File::CREATE) do |zipfile|
    
	  params[:ids].each_with_index do |id, index|
		# select issue_attachment in exact order as selected in index
		issue_attachment = @issue_attachments.select { |ia| ia.id == id.to_i }.first
	    
	    archive_filename = ("%0#{num_digits}d" % index).to_s + "_" + issue_attachment.filename

		# append current pdf
		zipfile.add( archive_filename, issue_attachment.diskfile) 
	  
	  end #each
    end #Zip
    
    big_data = File.read(tmp_zipfile.path)
    
	send_data big_data, 
			  :filename => "download.zip",
			  :type => "application/zip",
			  :x_sendfile => true
			  
	# we cannot close the file, send_file works asynchronous	
	# therefore we loaded data into memory and send it
	# with send_data.
	# this may be problematic with large files	  
    tmp_zipfile.unlink
    return
    
  end #def

  # ------------------------------------------------------------------------------#
  def bulk_categorize

    if IssueAttachment.method_defined?(:attachment_category)  
      editable_ids = @issue_attachments.map {|ia| ia.editable? ? ia.id : nil }.compact
      Attachment.where(:id => editable_ids).update_all(:attachment_category_id => params[:attachment_category_id])
    end #if

    redirect_to :back

  end #def
  
  # ------------------------------------------------------------------------------#
  def bulk_delete
  
    @issue_attachments.each do |ia|
      if ia.deletable?
		if ia.container.respond_to?(:init_journal)
		   ia.container.init_journal(User.current)
		end
		if ia.container
		  # Make sure association callbacks are called
		  ia.container.attachments.delete(ia)
		else
		  ia.destroy
		end
	  end #do 
    end #if
    
    redirect_to :back
    
  end #def  

  # ------------------------------------------------------------------------------#
  def issue_attachments_menu
  
    if (@issue_attachments.size == 1)
      @issue_attachment = @issue_attachments.first
    end
    
    # important: order ids in the seqence as they had been posted
    @issue_attachment_ids = @issue_attachments.sort_by {|x| params[:ids].index "#{x.id}" }
    
    @can = {:pdf    => @issue_attachments.all? { |ia| 
    				     ia.is_pdf? 
    	               },
    	    :delete => (@issue_attachments.all? { |ia| 
    	                 ia.deletable?
    	               } &&
    	               User.current.allowed_to?({:controller => params[:controller], 
    	                                         :action => :bulk_delete }, 
    	                                         @project || @projects, 
    	                                         :global => false
    	                                        )
    	               ),
    	    :edit   => (@issue_attachments.all? { |ia| 
    	                 ia.editable?
    	               } &&
    	               User.current.allowed_to?({:controller => params[:controller], 
    	                                         :action => :bulk_categorize }, 
    	                                         @project || @projects, 
    	                                         :global => false
    	                                        )
    	               )
    }
    
    render :layout => false

  end #def
  
  
  # ------------------------------------------------------------------------------#
  # ------------------------------------------------------------------------------#
private

  # ------------------------------------------------------------------------------#
  # Find a project based on params[:project_id]
  def find_optional_project
	if params[:project_id].present?
	  @project = Project.find(params[:project_id]) 
	  true
	elsif params[:id].present?
	  @project = Project.find(params[:id]) 
	  true
	else
	  allowed = User.current.allowed_to?({:controller => params[:controller], :action => params[:action]}, @project, :global => true)
	  allowed ? true : deny_access
	end
  rescue ActiveRecord::RecordNotFound
	render_404
  end #def

  # ------------------------------------------------------------------------------#
  # Find issues with a single :id param or :ids array param
  # Raises a Unauthorized exception if one of the issues is not visible
  def find_issue_attachments
    @issue_attachments = []
    @issue_attachments+= IssueAttachment.visible.
      where(:id => (params[:ids].map(&:to_i))).
      preload(:author, :project).
      to_a if params[:ids].present?
   raise ActiveRecord::RecordNotFound if @issue_attachments.empty?
   raise Unauthorized unless @issue_attachments.all?(&:visible?)
    @projects = @issue_attachments.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
   rescue ActiveRecord::RecordNotFound
	 render_404
  end #def


end
